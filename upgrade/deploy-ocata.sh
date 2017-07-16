#!/usr/bin/env bash

source ~/stackrc

time openstack overcloud deploy --templates \
-e /usr/share/openstack-tripleo-heat-templates/environments/low-memory-usage.yaml \
-e /usr/share/openstack-tripleo-heat-templates/environments/storage-environment.yaml \
-e ~/tripleo-ceph-ansible/upgrade/tht/ocata.yaml
