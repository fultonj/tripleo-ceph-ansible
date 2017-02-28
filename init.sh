#!/usr/bin/env bash

FORK=0
HACK=0
CLONE=1
RPM=0

if [ $FORK -eq 1 ]; then
    # (OLD) use fork given https://github.com/d0ugal/mistral-ansible-actions/pull/1
    git clone -b extra_vars_args_to_limit https://github.com/fultonj/mistral-ansible-actions.git
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

if [ $HACK -eq 1 ]; then
    # use this workaround for now
    id mistral
    if [ ! -d /home/mistral ]; then
	sudo mkdir /home/mistral
    fi
    sudo chown mistral:mistral /home/mistral/
    sudo cp -r ~/.ssh/ /home/mistral/
    sudo chown -R mistral:mistral /home/mistral/.ssh/
fi

if [ $CLONE -eq 1 ]; then
    git clone git@github.com:ceph/ceph-ansible.git
fi

if [ $RPM -eq 1 ]; then
    # The latest ceph-ansible CI RPM builds are listed at
    # https://shaman.ceph.com/repos/ceph-ansible/master/
    # https://shaman.ceph.com/api/repos/ceph-ansible/master/latest/centos/7/repo?arch=noarch
    pushd /etc/yum.repos.d
    curl https://2.chacra.ceph.com/repos/ceph-ansible/master/661a9d0cdf35eb7d4b40ae25eaf4e8caa0e2dd18/centos/7/flavors/default/repo > ceph.repo
    popd
    yum -y install ceph-ansible 
fi
