#!/usr/bin/env bash

source ~/stackrc

WORKBOOK=/home/stack/tripleo-common/workbooks/ceph-ansible.yaml
if [[ ! -e $WORKBOOK ]]; then
    echo "$WORKBOOK does not exist (see init.sh)"
    exit 1
fi

EXISTS=$(mistral workbook-list | grep tripleo.storage.v1 | wc -l)
if [[ $EXISTS -gt 0 ]]; then
    mistral workbook-update $WORKBOOK
else
    mistral workbook-create $WORKBOOK
fi

time openstack overcloud deploy --templates ~/templates \
-e ~/templates/environments/ceph-ansible/ceph-ansible.yaml \
-e ~/templates/environments/puppet-pacemaker.yaml \
-e ~/templates/environments/low-memory-usage.yaml \
-e ~/templates/environments/disable-telemetry.yaml \
-e ~/tripleo-ceph-ansible/tht/overcloud-ceph-ansible.yaml


# -e ~/templates/environments/docker.yaml \
