#!/usr/bin/env bash 

DNS=1

IRONIC=1

CEPH_ANSIBLE=1
CEPH_ANSIBLE_GITHUB=0 # try latest ceph-ansible
GIT_SSH=0

THT=1

WORKBOOK=1

source ~/stackrc

if [ $DNS -eq 1 ]; then
    openstack subnet list 
    SNET=$(openstack subnet list | awk '/192/ {print $2}')
    openstack subnet show $SNET
    openstack subnet set $SNET --dns-nameserver 10.19.143.247 --dns-nameserver 10.19.143.248
    openstack subnet show $SNET
fi

if [ $IRONIC -eq 1 ]; then
    echo "Updating ironic ceph nodes with ceph-storage profiles"
    for i in $(seq 0 2); do 
	ironic node-update ceph-$i replace properties/capabilities=profile:ceph-storage,boot_option:local
    done
fi

if [ $CEPH_ANSIBLE -eq 1 ]; then
    echo "Ensuring /usr/share/ceph-ansible does not exist"
    sudo rm -rf /usr/share/ceph-ansible/
    
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
    stat /usr/share/ceph-ansible/site-docker.yml.sample
fi

if [ $THT -eq 1 ]; then
    dir=/home/stack/tripleo-heat-templates
    pushd $dir
    git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/66/465066/19 && git checkout FETCH_HEAD
    popd
    # pushd /home/stack/tripleo-ceph-ansible/tht2mistral
    # bash install.sh
    # popd
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
    fi
    echo "Patching ~/tripleo-common with newer unmerged changes from the following:"
    echo "- https://review.openstack.org/#/c/469644"
    pushd $dir
    git fetch git://git.openstack.org/openstack/tripleo-common refs/changes/44/469644/15 && git checkout FETCH_HEAD
    popd
fi
