#!/usr/bin/env bash

source ~/stackrc

WORKBOOK_DEV=0 # workbook is merged; are you developing it more?
if [[ $WORKBOOK_DEV -gt 0 ]]; then

    # is skip_tags commented out?
    grep skip ~/tripleo-common/workbooks/ceph-ansible.yaml

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
fi

time openstack overcloud deploy --templates ~/templates \
-r ~/tripleo-ceph-ansible/tht/roles_data.yaml \
-e ~/templates/environments/ceph-ansible/ceph-ansible.yaml \
-e ~/templates/environments/ceph-ansible/ceph-mds.yaml \
-e ~/templates/environments/puppet-pacemaker.yaml \
-e ~/templates/environments/low-memory-usage.yaml \
-e ~/templates/environments/disable-telemetry.yaml \
-e ~/tripleo-ceph-ansible/tht/overcloud-ceph-ansible.yaml

# still getting http://sprunge.us/dSUR
# -e ~/templates/environments/docker.yaml \
