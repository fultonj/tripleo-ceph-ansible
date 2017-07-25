#!/bin/bash

ansible-playbook site-docker.yml.sample \
--user heat-admin --become --become-user root \
--forks 5 --ssh-extra-args "-o StrictHostKeyChecking=no" \
--skip-tags package-install,with_pkg \
--extra-vars "@input.json"

ansible mons,clients -b -m shell -a "hostname; getfacl /etc/ceph/ceph.client.openstack.keyring"
