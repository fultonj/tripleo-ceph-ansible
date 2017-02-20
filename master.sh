#!/usr/bin/env bash

if [ ! -d /home/stack/oooq ]; then
    echo "/home/stack/oooq is missing please install with:"
    echo "git clone https://github.com/fultonj/oooq.git /home/stack/oooq"
fi

if [ ! -d /home/stack/tripleo-ceph-ansible ]; then
    echo "/home/stack/tripleo-ceph-ansible is missing please install with:"
    echo "git clone https://github.com/fultonj/tripleo-ceph-ansible.git /home/stack/tripleo-ceph-ansible"
fi

echo "Install OpenStack"
date 
pushd /home/stack/oooq
bash deploy-mistral-ceph-hci.sh
popd

echo "Install Ceph with Mistral/ceph-ansible"
date
pushd /home/stack/tripleo-ceph-ansible
bash mistral-ceph-ansible.sh
echo "Restart OpenStack services which use Ceph"
date
bash connect_osp_ceph.sh
echo "Test connection between Ceph and OpenStack"
date
bash sanity-check.sh 
popd
