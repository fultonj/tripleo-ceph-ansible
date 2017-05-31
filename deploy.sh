#!/usr/bin/env bash

source ~/stackrc

EXISTS=$(mistral workbook-list | grep tripleo.ceph-ansible.v1 | wc -l)
if [[ $EXISTS -gt 0 ]]; then
    mistral workbook-update /home/stack/tripleo-ceph-ansible/ceph-ansible.yaml
else
    mistral workbook-create /home/stack/tripleo-ceph-ansible/ceph-ansible.yaml
fi

time openstack overcloud deploy --templates ~/templates \
-r ~/tripleo-ceph-ansible/tht/roles_data.yaml \
-e ~/templates/environments/ceph_ansible/ceph_ansible.yaml \
-e ~/templates/environments/puppet-pacemaker.yaml \
-e ~/templates/environments/low-memory-usage.yaml \
-e ~/tripleo-ceph-ansible/tht/overcloud-ceph-ansible.yaml
