#!/usr/bin/env bash

MISTRAL=1
MISTRAL_FORK=0
MISTRAL_PRIV=1

CEPH_ANSIBLE=1
CEPH_ANSIBLE_MASTER=0

HEAT=1
THT=1

source ~/stackrc

if [ $MISTRAL -eq 1 ]; then
    echo "Installing Mistral Ansbile actions from out of tree"
    # https://github.com/d0ugal/mistral-ansible-actions
    if [ $MISTRAL_FORK -eq 1 ]; then
	# pull from my work isntead of pip
	git clone https://github.com/fultonj/mistral-ansible-actions.git
	sudo rm -Rf /usr/lib/python2.7/site-packages/mistral_ansible*
	pushd mistral-ansible-actions
	sudo python setup.py install
	popd
    else
	sudo yum install -y python-pip
	sudo pip install mistral-ansible-actions;
    fi    
    sudo mistral-db-manage populate;
    sudo systemctl restart openstack-mistral*;
    mistral action-list | grep ansible
    echo "Try these:"
    echo "  mistral action-get ansible"
    echo "  mistral action-get ansible-playbook"
    
    if [ $MISTRAL_PRIV -eq 1 ]; then
	# use this workaround for now
	id mistral
	if [ ! -f /etc/sudoers.d/mistral ]; then
	    # escalate mistral users privs so he can run inventory script (for now)
	    sudo sh -c "echo \"mistral ALL=(root) NOPASSWD:ALL\" | tee -a /etc/sudoers.d/mistral "
	    sudo chmod 0440 /etc/sudoers.d/mistral
	fi
	# set stack user password so mistral can SSH in (for now)
	sudo usermod --password $(echo stack | openssl passwd -1 -stdin) stack
	
	# I think this can go, but want to test first
	if [ ! -d /home/mistral ]; then
	    sudo mkdir /home/mistral
	fi
	sudo chown mistral:mistral /home/mistral/
	sudo cp -r ~/.ssh/ /home/mistral/
	sudo chown -R mistral:mistral /home/mistral/.ssh/
    fi
fi

if [ $CEPH_ANSIBLE -eq 1 ]; then
    echo "Installing ceph-ansible in /usr/share"
    if [ $CEPH_ANSIBLE_MASTER -eq 1]; then 
	git clone git@github.com:ceph/ceph-ansible.git
	sudo mv ceph-ansible /usr/share/
    else
	# The latest ceph-ansible CI RPM builds are listed at
	# https://shaman.ceph.com/repos/ceph-ansible/master/
	# https://shaman.ceph.com/api/repos/ceph-ansible/master/latest/centos/7/repo?arch=noarch
	pushd /etc/yum.repos.d
	sudo sh -c "curl https://2.chacra.ceph.com/repos/ceph-ansible/master/661a9d0cdf35eb7d4b40ae25eaf4e8caa0e2dd18/centos/7/flavors/default/repo > ceph.repo"
	popd
	sudo yum -y install ceph-ansible
	stat /usr/share/ceph-ansible/site.yml.sample
    fi
    
    echo "Disabling Ansible host key checking"
    # https://github.com/openstack/tripleo-validations/blob/master/ansible.cfg#L3
    sudo sed -i -e s/\#host_key_checking\ =\ False/host_key_checking=False/g /etc/ansible/ansible.cfg

    echo "Updating /etc/ansible/ansible.cfg action_plugins=/usr/share/ceph-ansible/plugins"
    sudo sed -i -e s/\#action_plugins.*/action_plugins\ \=\ \\/usr\\/share\\/ceph-ansible\\/plugins\\/actions/g /etc/ansible/ansible.cfg
fi

if [ $HEAT -eq 1 ]; then
    echo "Installing new Heat Resource from https://review.openstack.org/#/c/420664/"
    # https://review.openstack.org/#/c/420664/
    sudo cp heat/workflow_execution.py /usr/lib/python2.7/site-packages/heat/engine/resources/openstack/mistral/
    sudo systemctl restart openstack-heat-engine
    openstack orchestration resource type show --template-type hot OS::Mistral::WorkflowExecution
fi

if [ $THT -eq 1 ]; then
    dir=/home/stack/tripleo-heat-templates
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
    echo "Patching ~/templates with unmerged changes from the following:"
    echo "- https://review.openstack.org/#/c/404499/"
    echo "- https://review.openstack.org/#/c/441137/"
    pushd $dir

    # download the smaller change
    git review -d 404499
    md5sum overcloud.j2.yaml overcloud-resource-registry-puppet.j2.yaml
    
    # download in the bigger change
    git review -d 441137
    # checksums should remain the same (no file conflicts here)
    md5sum overcloud.j2.yaml overcloud-resource-registry-puppet.j2.yaml
    popd

    # update ceph-ansible-workflow.j2.yaml to pass other parameters
    cp -v -f tht/ceph-ansible-workflow.j2.yaml $dir/extraconfig/tasks/ceph-ansible-workflow.j2.yaml
fi
