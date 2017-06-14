#!/usr/bin/env bash

DNS=1

IRONIC=1

MISTRAL=1
MISTRAL_FORK=1

CEPH_ANSIBLE=1
CEPH_ANSIBLE_MASTER=0 

THT=1

WORKBOOK=1
PRIKEY=1    # only works in WORKBOOK=1

source ~/stackrc

if [ $DNS -eq 1 ]; then
    neutron subnet-list
    SNET=$(neutron subnet-list | awk '/192/ {print $2}')
    neutron subnet-show $SNET
    neutron subnet-update ${SNET} --dns-nameserver 10.19.143.247 --dns-nameserver 10.19.143.248 
    neutron subnet-show $SNET
fi

if [ $IRONIC -eq 1 ]; then
    echo "Updating ironic nodes with compute and control profiles for their respective flavors"
    ironic node-update ceph-0 replace properties/capabilities=profile:compute,boot_option:local
    ironic node-update control-0 replace properties/capabilities=profile:control,boot_option:local
fi

if [ $MISTRAL -eq 1 ]; then
    # this should be updated to pull from https://review.openstack.org/#/c/470021/
    echo "Installing Mistral Ansbile actions from out of tree"
    # https://github.com/d0ugal/mistral-ansible-actions
    if [ $MISTRAL_FORK -eq 1 ]; then
	# pull from git instead of pip
	sudo rm -rf mistral-ansible-actions/
	git clone https://github.com/fultonj/mistral-ansible-actions.git
	# git clone https://github.com/d0ugal/mistral-ansible-actions.git	
	sudo rm -Rf /usr/lib/python2.7/site-packages/mistral_ansible*
	pushd mistral-ansible-actions
	sudo python setup.py install
	popd
    else
	sudo yum install -y python-pip
	sudo pip install mistral-ansible-actions;
    fi
    sudo mistral-db-manage populate;
    # apply fix for https://review.openstack.org/#/c/462917 (not necessary with new action)
    #sudo sed -i s/workflow2/workflowv2/g /usr/lib/python2.7/site-packages/mistralclient/auth/keystone.py 
    sudo systemctl restart openstack-mistral*;
    mistral action-list | grep ansible
    echo "Try these:"
    echo "  mistral action-get ansible"
    echo "  mistral action-get ansible-playbook"
fi

if [ $CEPH_ANSIBLE -eq 1 ]; then
    echo "Ensuring /{tmp,usr/share}/ceph-ansible does not exist"
    sudo rm -rf /tmp/ceph-ansible/
    
    echo "Installing ceph-ansible in /usr/share"
    if [ $CEPH_ANSIBLE_MASTER -eq 1 ]; then 
	echo "Cloning master from it"
	git clone git@github.com:ceph/ceph-ansible.git
	sudo mv ceph-ansible /usr/share/
	sudo chown -R root:root /usr/share/ceph-ansible
    else
	bash install-ceph-ansible.sh
    fi
    stat /usr/share/ceph-ansible/site.yml.sample
    
    echo "Disabling Ansible host key checking"
    # https://github.com/openstack/tripleo-validations/blob/master/ansible.cfg#L3
    sudo sed -i -e s/\#host_key_checking\ =\ False/host_key_checking=False/g /etc/ansible/ansible.cfg

    echo "Updating /etc/ansible/ansible.cfg action_plugins=/usr/share/ceph-ansible/plugins"
    sudo sed -i -e s/\#action_plugins.*/action_plugins\ \=\ \\/usr\\/share\\/ceph-ansible\\/plugins\\/actions/g /etc/ansible/ansible.cfg

    echo "Disable retry files given permissions issue with /usr/share (for now)"
    sudo sed -i s/\#retry_files_enabled\ =\ False/retry_files_enabled\ =\ False/g /etc/ansible/ansible.cfg

    echo "Disable deprecation warnings"
    sudo sed -i s/\#deprecation_warnings\ =\ True/deprecation_warnings\ =\ False/g /etc/ansible/ansible.cfg
fi

if [ $THT -eq 1 ]; then
    pushd /home/stack/tripleo-ceph-ansible/tht2mistral
    bash install.sh
    popd
fi

if [ $WORKBOOK -eq 1 ]; then
    dir=/home/stack/tripleo-common
    if [ ! -d  $dir ]; then
	# https://github.com/fultonj/oooq/blob/master/setup-deploy-artifacts.sh
	echo "$dir is missing; please git clone it from review.openstack.org"
	exit 1
    fi
    if [[ $(ssh-add -l | wc -l) -eq 0 ]]; then
	# did they forward their SSH key?
	echo "No SSH agent with keys present. Will not be able to connect to git."
	exit 1
    fi
    echo "Patching ~/tripleo-common with newer unmerged changes from the following:"
    echo "- https://review.openstack.org/#/c/469644"
    pushd $dir
    git review -d 469644
    popd
    if [ $PRIKEY -eq 1 ]; then
	echo "Adding new mistral action get_private_key from updated tripleo_common"
	sudo diff -u /usr/lib/python2.7/site-packages/tripleo_common/actions/validations.py /home/stack/tripleo-common/tripleo_common/actions/validations.py 
	grep GetPrikeyAction /home/stack/tripleo-common/setup.cfg
	sudo rm -Rf /usr/lib/python2.7/site-packages/tripleo_common*
	pushd $dir
	sudo python setup.py install
	sudo cp /usr/share/tripleo-common/sudoers /etc/sudoers.d/tripleo-common
	sudo systemctl restart openstack-mistral-executor
	sudo systemctl restart openstack-mistral-engine
	sudo mistral-db-manage populate
	popd
	mistral action-list | grep tripleo.validations.get_
    fi
fi

