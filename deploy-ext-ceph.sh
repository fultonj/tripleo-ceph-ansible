#!/usr/bin/env bash

source ~/stackrc

WORKBOOK_DEV=1 # workbook updated 
if [[ $WORKBOOK_DEV -gt 0 ]]; then
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
-e ~/templates/environments/docker.yaml \
-e ~/templates/environments/docker-ha.yaml \
-e ~/templates/environments/low-memory-usage.yaml \
-e ~/templates/environments/disable-telemetry.yaml \
-e ~/docker_registry.yaml \
-e ~/templates/environments/ceph-ansible/ceph-ansible-external.yaml \
-e ~/tripleo-ceph-ansible/tht/overcloud-ceph-ansible-external.yaml
