#!/usr/bin/env bash 

DNS=1
ZAP=1
IRONIC=1

CEPH_ANSIBLE=1
CEPH_ANSIBLE_GITHUB=0 # try latest ceph-ansible
GIT_SSH=0

THT=0
WORKBOOK=0
OSP_CONTAINERS=1

source ~/stackrc

if [ $DNS -eq 1 ]; then
    openstack subnet list 
    SNET=$(openstack subnet list | awk '/192/ {print $2}')
    openstack subnet show $SNET
    openstack subnet set $SNET --dns-nameserver 10.19.143.247 --dns-nameserver 10.19.143.248
    openstack subnet show $SNET
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

if [ $IRONIC -eq 1 ]; then
    echo "Updating ironic ceph storage nodes with ceph-storage profiles"
    for i in $(seq 0 2); do 
	ironic node-update ceph-$i replace properties/capabilities=profile:ceph-storage,boot_option:local
    done
    # mds
    echo "Updating ironic ceph mds node with ceph-mds profile"
    openstack flavor create --id auto --ram 4096 --disk 40 --vcpus 2 ceph-mds
    openstack flavor set --property "cpu_arch"="x86_64" --property "capabilities:boot_option"="local" --property "capabilities:profile"="ceph-mds" ceph-mds
    openstack flavor show ceph-mds
    ironic node-update mds-0 replace properties/capabilities=profile:ceph-mds,boot_option:local
    # rgw
    echo "Updating ironic ceph rgw node with ceph-rgw profile"
    openstack flavor create --id auto --ram 4096 --disk 40 --vcpus 2 ceph-rgw
    openstack flavor set --property "cpu_arch"="x86_64" --property "capabilities:boot_option"="local" --property "capabilities:profile"="ceph-rgw" ceph-rgw
    openstack flavor show ceph-rgw
    ironic node-update rgw-0 replace properties/capabilities=profile:ceph-rgw,boot_option:local
fi

if [ $CEPH_ANSIBLE -eq 1 ]; then
    
    echo "Installing ceph-ansible in /usr/share"
    if [ $CEPH_ANSIBLE_GITHUB -eq 1 ]; then
	echo "Cloning ceph-ansible from github"
	if [ $GIT_SSH -eq 1 ]; then
	    git clone git@github.com:ceph/ceph-ansible.git 
	    #git clone git@github.com:fultonj/ceph-ansible.git 
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
    dir=/home/stack/tripleo-heat-templates
    pushd $dir
    git review -d 492082
    #git review -d 479426
    popd
    echo "Apply this manually too: https://review.openstack.org/#/c/492303/1/docker/services/ceph-ansible/ceph-base.yaml"
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
    echo "- https://review.openstack.org/#/c/480771"
    pushd $dir
    git review -d 487650

    echo "Manually apply fixes from https://review.openstack.org/#/c/485004/"
    for f in $(echo container-images/overcloud_containers.yaml{,.j2}); do
	grep tag-build-master-jewel-centos-7 $f ;
	sed -i '/tag-build-master-jewel-centos-7/d' $f
	grep tag-build-master-jewel-centos-7 $f ;
    done
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
