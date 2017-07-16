Migrate Ceph to Containers with TripleO during Ocata to Pike Upgrade
====================================================================

Scenario
--------

- Use TripleO Ocata with THT/puppet-ceph to deploy RDO Ocata and Ceph 
- Upgrade TripleO Ocata to TripleO Pike 
- Use TripleO Pike with THT/mistral/ceph-ansible to upgrade Ceph
- The upgrade should [containerize](https://www.sebastien-han.fr/blog/2016/09/26/Ceph-migrate-from-non-containerized-to-containers-daemons/) all Ceph deamons 

Phases
------

1. Manually run playbooks (e.g. [switch-from-non-containerized-to-containerized-ceph-daemons.yml](https://github.com/ceph/ceph-ansible/blob/master/infrastructure-playbooks/switch-from-non-containerized-to-containerized-ceph-daemons.yml)) on the undercloud
2. Modify [tripleo-common/workbooks/ceph-ansible.yaml](https://review.openstack.org/#/c/469644) to call the playbook from Mistral in a new workflow 
3. Modify Heat to call the new workflow during overcloud upgrade

Environment
-----------

The following is for Phase 1

- Deploy Ocata undercloud with quickstart with `--release ocata`
- Prepare undercloud with [init.sh](../init.sh) without THT, WORKBOOK, or OSP_CONTAINERS
- Deploy Ocata overcloud with Ceph using [deploy-ocata.sh](deploy-ocata.sh)
- Build the inventory with
- Import the ceph cluster into ceph-ansible with a [playbook](https://github.com/ceph/ceph-ansible/blob/master/infrastructure-playbooks/take-over-existing-cluster.yml)
- Containerize the ceph cluster with a [playbook](https://github.com/ceph/ceph-ansible/blob/master/infrastructure-playbooks/switch-from-non-containerized-to-containerized-ceph-daemons.yml)
