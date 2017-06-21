#!/usr/bin/env bash

source ~/stackrc

# workaround
if [[ -d /tmp/ceph-ansible-fetch/ ]]; then
    sudo rm -rf /tmp/ceph-ansible-fetch/
fi
sudo mkdir /tmp/ceph-ansible-fetch/
sudo chown mistral:mistral /tmp/ceph-ansible-fetch/

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
-e ~/templates/environments/ceph_ansible/ceph_ansible.yaml \
-e ~/templates/environments/puppet-pacemaker.yaml \
-e ~/templates/environments/low-memory-usage.yaml \
-e ~/templates/environments/disable-telemetry.yaml \
-e ~/tripleo-ceph-ansible/tht/overcloud-ceph-small-ansible.yaml

# workaround
sudo rm -rf /tmp/ceph-ansible-fetch/
