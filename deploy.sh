#!/usr/bin/env bash

source ~/stackrc

WORKBOOK_DEV=0 # workbook updated 
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
-e ~/templates/environments/low-memory-usage.yaml \
-e ~/templates/environments/disable-telemetry.yaml \
-e ~/templates/environments/docker-centos-tripleoupstream.yaml \
-e ~/templates/environments/ceph-ansible/ceph-ansible.yaml \
-e ~/tripleo-ceph-ansible/tht/overcloud-ceph-ansible.yaml

# set mds aside for now
#-e ~/templates/environments/ceph-ansible/ceph-mds.yaml \
#-r ~/tripleo-ceph-ansible/tht/roles_data.yaml \

# Had http://sprunge.us/dPaH using docker-ha with ceph-ansible
#-e ~/templates/environments/docker-ha.yaml \
