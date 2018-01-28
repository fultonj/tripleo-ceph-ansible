#!/usr/bin/env bash
# Filename:                init.sh
# Description:             Prepare quickstart env for dev
# Supported Langauge(s):   GNU Bash 4.x + OpenStack Pike
# Time-stamp:              <2018-01-28 16:24:29 fultonj> 
# -------------------------------------------------------
DNS=1
IRONIC=1
ZAP=1

CEPH_ANSIBLE=1
CEPH_ANSIBLE_GITHUB=0 # try latest ceph-ansible
GIT_SSH=1

THT=1
WORKBOOK=0
OSP_CONTAINERS=1
SLOW=0

source ~/stackrc

# determine environment where hypervisor is
RAM=$(grep MemTotal /proc/meminfo | awk {'print $2'})
if [[ $RAM == 13* ]]; then 
    HOST="orthanc" # about 12G
else
    HOST="lab"
fi
# override to slow hardware from lab for now
if [ $SLOW -eq 1 ]; then
    HOST="lab"
fi


if [ $DNS -eq 1 ]; then
    openstack subnet list 
    SNET=$(openstack subnet list | awk '/192/ {print $2}')
    openstack subnet show $SNET
    if [[ "$HOST" = "lab" ]]; then
	# internal dns servers for systems engineering lab
	# s/set/unset to undo
	openstack subnet set $SNET --dns-nameserver 10.19.143.247 --dns-nameserver 10.19.143.248
    fi
    if [[ "$HOST" = "orthanc" ]]; then
	# https://www.opendns.com/
	openstack subnet set $SNET --dns-nameserver 208.67.222.123 --dns-nameserver 208.67.220.123
    fi
    openstack subnet show $SNET
fi

if [ $IRONIC -eq 1 ]; then

    if [[ "$HOST" = "orthanc" ]]; then
	ceph_node_numbers=0
	MDS=0
	RGW=0
	
	echo "Redefine compute with smaller flavor"
	openstack flavor delete compute
	openstack flavor create --id auto --ram 1024 --disk 40 --vcpus 1 compute
	openstack flavor set --property "cpu_arch"="x86_64" --property "capabilities:boot_option"="local" --property "capabilities:profile"="compute" compute
	openstack flavor show compute

	echo "Update CephStorageCount in THT"
	layout=tht/overcloud-ceph-ansible.yaml
	grep CephStorageCount $layout
	sed -i -e s/CephStorageCount:\ 3/CephStorageCount:\ 1/g $layout
	grep CephStorageCount $layout
	
    else
	ceph_node_numbers=$(seq 0 2)
	MDS=0
	RGW=0
    fi
    
    echo "Updating ironic ceph storage nodes with ceph-storage profiles"
    for i in $ceph_node_numbers; do 
	ironic node-update ceph-$i replace properties/capabilities=profile:ceph-storage,boot_option:local
    done

    for id in $(openstack baremetal node list | grep ceph | awk {'print $2'}); do
	# I told oooq to give me a ceph node so it gave me extra disks.
	# I got /dev/vda with 50G (like other nodes) but /dev/vd{b,c,d}
	# had 7G. So introspection reported local_gb at 7 for a small disk
	# and the nova scheduler would think the image would not fit.
	#echo $id	
	openstack baremetal node set $id --property local_gb="50"
	openstack baremetal node set $id --property root_device='{"size": "50"}'	
	ironic node-show $id | egrep "local_gb|50";
    done
    
    if [ $MDS -eq 1 ]; then
	# mds
	echo "Updating ironic ceph mds node with ceph-mds profile"
	openstack flavor create --id auto --ram 4096 --disk 40 --vcpus 2 ceph-mds
	openstack flavor set --property "cpu_arch"="x86_64" --property "capabilities:boot_option"="local" --property "capabilities:profile"="ceph-mds" ceph-mds
	openstack flavor show ceph-mds
	ironic node-update mds-0 replace properties/capabilities=profile:ceph-mds,boot_option:local
    fi
    if [ $RGW -eq 1 ]; then    
	# rgw
	echo "Updating ironic ceph rgw node with ceph-rgw profile"
	openstack flavor create --id auto --ram 4096 --disk 40 --vcpus 2 ceph-rgw
	openstack flavor set --property "cpu_arch"="x86_64" --property "capabilities:boot_option"="local" --property "capabilities:profile"="ceph-rgw" ceph-rgw
	openstack flavor show ceph-rgw
	ironic node-update rgw-0 replace properties/capabilities=profile:ceph-rgw,boot_option:local
    fi
fi

if [ $ZAP -eq 1 ]; then
    # http://blog.johnlikesopenstack.com/2017/03/ironic-metadata-disk-cleaning-instead.html
    echo "Enabling Ironic Metadata Disk Cleaning"
    sudo egrep "clean|erase" /etc/ironic/ironic.conf | egrep -v \#
    sudo sed -i s/automated_clean=False/automated_clean=True/g /etc/ironic/ironic.conf
    sudo egrep "clean|erase" /etc/ironic/ironic.conf | egrep -v \#
    sudo systemctl restart openstack-ironic-conductor.service
    sudo systemctl status openstack-ironic-conductor.service

    echo "Cleaning Ceph Nodes for first time (this will run automatically next time)"
    for ironic_id in $(ironic node-list | grep ceph | awk {'print $2'} | grep -v UUID | egrep -v '^$'); do
	ironic node-set-provision-state $ironic_id manage; 
    done 

    for ironic_id in $(ironic node-list  | grep ceph | awk {'print $2'} | grep -v UUID | egrep -v '^$'); do 
	ironic node-set-provision-state $ironic_id provide; 
    done
    ironic node-list
fi

if [ $CEPH_ANSIBLE -eq 1 ]; then
    
    echo "Installing ceph-ansible in /usr/share"
    if [ $CEPH_ANSIBLE_GITHUB -eq 1 ]; then
	echo "Cloning ceph-ansible from github"
	if [ $GIT_SSH -eq 1 ]; then
	    git clone git@github.com:ceph/ceph-ansible.git 
	else
	    git clone https://github.com/ceph/ceph-ansible.git
	fi
	sudo mv ceph-ansible /usr/share/
	sudo chown -R root:root /usr/share/ceph-ansible
    else
	bash install-ceph-ansible.sh
    fi
fi

if [ $THT -eq 1 ]; then
    openstack overcloud roles generate -o ~/roles_data.yaml ControllerNoCeph HciCephAll
    #dir=/home/stack/tripleo-heat-templates
    #pushd $dir
    #git review -d 499627
    #popd
fi

if [ $WORKBOOK -eq 1 ]; then
    dir=/home/stack/tripleo-common
    if [ ! -d  $dir ]; then
	# https://github.com/fultonj/oooq/blob/master/setup-deploy-artifacts.sh
	echo "$dir is missing; please git clone it from review.openstack.org"
	exit 1
    fi
    if [[ ${GIT_SSH} -eq 1 && $(ssh-add -l | wc -l) -eq 0 ]]; then
	# did they forward their SSH key?
	echo "No SSH agent with keys present. Will not be able to connect to git."
	exit 1
    fi
    echo "Patching ~/tripleo-common with newer unmerged changes from the following:"
    echo "- https://review.openstack.org/#/c/537662/"
    pushd $dir
    git review -d 537662
    popd
fi


if [ $OSP_CONTAINERS -eq 1 ]; then
    # templates/environments/docker-centos-tripleoupstream.yaml is removed
    # http://lists.openstack.org/pipermail/openstack-dev/2017-July/119880.html
    # openstack overcloud container image prepare --env-file=$HOME/containers.yaml
    openstack overcloud container image prepare \
	--namespace tripleoupstream \
	--tag latest \
	--env-file ~/docker_registry.yaml
fi

if [ $SLOW -eq 1 ]; then
    echo "Increasing ceph-ansible ssh timeout to deal with slow hardware"
    # https://bugs.launchpad.net/tripleo/+bug/1745108
    crudini --get /usr/share/ceph-ansible/ansible.cfg defaults timeout
    sudo crudini --set /usr/share/ceph-ansible/ansible.cfg defaults timeout 180
    crudini --get /usr/share/ceph-ansible/ansible.cfg defaults timeout    
fi
