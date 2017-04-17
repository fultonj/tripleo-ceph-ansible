TripleO Installing Ceph with Ceph-Ansible POC
=============================================

This repository hosts POCs of the TripleO spec [Enable TripleO to Deploy Ceph via Ceph Ansible](https://specs.openstack.org/openstack/tripleo-specs/specs/pike/tripleo-ceph-ansible-integration.html). 

The [initial milestones](milesones.md) have been accomplished and we
have a video demo: 

[![TripleO ceph-ansible POC Demo](https://img.youtube.com/vi/YWSsl6OrORY/0.jpg)](https://www.youtube.com/watch?v=YWSsl6OrORY)

Try POC
-------

- Install [TripleO Quickstart](https://github.com/openstack/tripleo-quickstart) (I use [myconfigfile.yml](https://github.com/fultonj/oooq/blob/master/myconfigfile.yml))
- Run [setup-deploy-artifacts.sh](https://github.com/fultonj/oooq/blob/master/setup-deploy-artifacts.sh)
- Clone this repository into the stack user's home directory and `cd tripleo-ceph-ansible`
- Run [init.sh](init.sh) (List of things we need to fix)
- Run [deploy.sh](deploy.sh)
