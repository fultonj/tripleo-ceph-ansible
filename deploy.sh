#!/usr/bin/env bash

source ~/stackrc

WORKFLOW='mistral-ceph-ansible'
EXISTS=$(mistral workflow-list | grep $WORKFLOW | wc -l)
if [[ $EXISTS -gt 0 ]]; then
    mistral workflow-update /home/stack/tripleo-ceph-ansible/$WORKFLOW.yaml
else
    mistral workflow-create /home/stack/tripleo-ceph-ansible/$WORKFLOW.yaml    
fi

time openstack overcloud deploy --templates ~/templates \
-e ~/templates/environments/ceph-ansible/ceph-ansible.yaml \
-e ~/templates/environments/puppet-pacemaker.yaml \
-e ~/templates/environments/low-memory-usage.yaml \
-e ~/tripleo-ceph-ansible/tht/overcloud-ceph-ansible.yaml
