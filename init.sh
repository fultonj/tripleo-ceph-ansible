#!/usr/bin/env bash 

DNS=1

IRONIC=1

CEPH_ANSIBLE=1
CEPH_ANSIBLE_GITHUB=0 # try latest ceph-ansible
GIT_SSH=0

THT=1

WORKBOOK=1

OSP_CONTAINERS=1

source ~/stackrc

if [ $DNS -eq 1 ]; then
    openstack subnet list 
    SNET=$(openstack subnet list | awk '/192/ {print $2}')
    openstack subnet show $SNET
    openstack subnet set $SNET --dns-nameserver 10.19.143.247 --dns-nameserver 10.19.143.248
    openstack subnet show $SNET
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
    echo "Applying https://github.com/ceph/ceph-ansible/pull/1682/commits"
    from="https://raw.githubusercontent.com/gfidente/ceph-ansible/7346f40d26348fec12e09e7cec52399dea3d80cc"
    to="/usr/share/ceph-ansible"

    for f in roles/ceph-mon/tasks/openstack_config.yml roles/ceph-mon/defaults/main.yml group_vars/mons.yml.sample; do
	curl $from/$f > foo 
	diff -u foo $to/$f
	sudo mv -v foo $to/$f
    done


    # Clients won't work until ceph-ansible is fixed:
    #   https://review.openstack.org/#/c/482500 
    #   https://bugzilla.redhat.com/show_bug.cgi?id=1469426 
    #   https://bugzilla.redhat.com/show_bug.cgi?id=1471152
    # 
    # echo "Adding manual update to site-docker.yml.sample"
    # echo "See https://github.com/ceph/ceph-ansible/commit/108503da961e78d28c45ee4c8fd1ea71b70abf27"
    # curl https://raw.githubusercontent.com/ceph/ceph-ansible/108503da961e78d28c45ee4c8fd1ea71b70abf27/site-docker.yml.sample > /tmp/site-docker.yml.sample
    # sudo mv /tmp/site-docker.yml.sample /usr/share/ceph-ansible/site-docker.yml.sample
fi

if [ $THT -eq 1 ]; then
    dir=/home/stack/tripleo-heat-templates
    pushd $dir
    # MDS pull (developing here) brings in stacked related change 465066
    git review -d 479426
#    git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/66/465066/21 && git checkout FETCH_HEAD
    popd
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
    git review -d 480771
    popd
fi


if [ $OSP_CONTAINERS -eq 1 ]; then
    echo "Setting up TripleO to use the pre-built images from registry on the dockerhub"
    echo "This usually takes 18 minutes"
    date
    # openstack overcloud container image upload --config-file /usr/share/openstack-tripleo-common/container-images/overcloud_containers.yaml
    time openstack overcloud container image upload --config-file ~/tripleo-common/container-images/overcloud_containers.yaml
fi
