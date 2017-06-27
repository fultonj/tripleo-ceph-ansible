#!/usr/bin/env bash 

DNS=0

IRONIC=0

CEPH_ANSIBLE=0
CEPH_ANSIBLE_GITHUB=0 # try latest ceph-ansible
GIT_SSH=0

THT=1

WORKBOOK=0
FILES=0 # https://review.openstack.org/#/c/477541

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
	    #git clone -b add_openstack_metrics_pool https://github.com/fultonj/ceph-ansible.git
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
    git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/66/465066/14 && git checkout FETCH_HEAD
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
	exit 1
    fi
    echo "Patching ~/tripleo-common with newer unmerged changes from the following:"
    echo "- https://review.openstack.org/#/c/469644"
    pushd $dir

    if [ $FILES -eq 1 ]; then
	git review -d 477541
	cp tripleo_common/actions/files.py ~/files.py-477541
	cp setup.cfg ~/setup.cfg-477541
	git checkout master
    fi
    
    git review -d 469644

    if [ $FILES -eq 1 ]; then
	echo "Patching ~/tripleo-common with newer unmerged changes from the following:"
	echo "- https://review.openstack.org/#/c/477541"

	cp ~/files.py-477541 tripleo_common/actions/files.py
	cp ~/setup.cfg-477541 setup.cfg

	sudo python setup.py install
	sudo cp /usr/share/tripleo-common/sudoers /etc/sudoers.d/tripleo-common
	sudo systemctl restart openstack-mistral-executor
	sudo systemctl restart openstack-mistral-engine
	sudo mistral-db-manage populate

	if [[ ! -e /usr/lib/python2.7/site-packages/tripleo_common/actions/files.pyc ]]; 
	then
	    echo "WARNING: files.py did not compile"
	fi
	action=tripleo.files
	grep $action /home/stack/tripleo-common/setup.cfg
	mistral action-list | grep $action
	if [[ ! $? -eq 0 ]]; then
	    echo "WARNING: $action action not found"
	fi
    fi
    popd
fi
