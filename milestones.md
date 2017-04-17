Milestones reached when trying to get Mistral to trigger Ceph-Ansible
=====================================================================

### Goal1: Deply Ceph on stand-alone Overcloud with ceph-ansible

- Set up TripleO-quickstart undercloud (works-for-me via [master.sh](https://github.com/fultonj/oooq/blob/master/master.sh))
- Deploy juice-boxes (works-for-me via [deploy-jeos.sh](https://github.com/fultonj/oooq/blob/master/deploy-jeos.sh))
- Run [mistral-ceph-ansible.sh](https://github.com/fultonj/tripleo-ceph-ansible/blob/master/mistral-ceph-ansible.sh) which executes the workflow [mistral-ceph-ansible.yaml](https://github.com/fultonj/tripleo-ceph-ansible/blob/master/mistral-ceph-ansible.yaml)

I have verified that the above works in my virtual environment. The
run takes less than 30 minutes. An example is in [session1.txt](https://github.com/fultonj/tripleo-ceph-ansible/blob/master/session1.txt).

### Goal1.5: Deploy HCI OpenStack/Ceph where Mistral installed Ceph

- Use [deploy-mistral-ceph-hci.sh](https://github.com/fultonj/oooq/blob/master/deploy-mistral-ceph-hci.sh) to deploy OpenStack to use an external Ceph cluster (which it will self-host)
- If the playbook is configured to [use br-ex instead of eth0](https://github.com/fultonj/tripleo-ceph-ansible/commit/e8b225911bca755e606d323ca108fbc161c38206), then the [same mistral workflow](https://github.com/fultonj/tripleo-ceph-ansible/blob/master/mistral-ceph-ansible.sh) will install Ceph on the same hosts.
- Then you just need to [restart nova, cinder, and glance](https://github.com/fultonj/tripleo-ceph-ansible/blob/master/connect_osp_ceph.sh) to have those services use Ceph and you can do a [sanity-check.sh](https://github.com/fultonj/tripleo-ceph-ansible/blob/master/sanity-check.sh).

### Goal 1.75: Deplopy ceph in containers 

see [session2.txt](https://github.com/fultonj/tripleo-ceph-ansible/blob/master/session2.txt).

### Goal 2: Deploy HCI OpenStack/Ceph with nothing but `openstack overcloud deploy...`

See my blog entry [Hackathon in Brno](http://blog.johnlikesopenstack.com/2017/03/hackathon-in-brno.html)

The following deploys such an overcloud provided that init.sh has been
run first.
```
[stack@undercloud tripleo-ceph-ansible]$ cat deploy.sh 
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
[stack@undercloud tripleo-ceph-ansible]$ 
```

Here is what it looks like (or see video demo linked from blog): 


```
[stack@undercloud tripleo-ceph-ansible]$ ./deploy.sh 
...

2017-04-17 19:56:33Z [overcloud]: CREATE_COMPLETE  Stack CREATE completed successfully

 Stack overcloud CREATE_COMPLETE 

/home/stack/.ssh/known_hosts updated.
Original contents retained as /home/stack/.ssh/known_hosts.old
Overcloud Endpoint: http://192.168.24.6:5000/v2.0
Overcloud Deployed

real    31m47.482s
user    0m4.635s
sys     0m0.495s
[stack@undercloud tripleo-ceph-ansible]$
```

Ceph is set up...

```
[stack@undercloud tripleo-ceph-ansible]$ ./sanity-check.sh 
 --------- ceph df --------- 
192.168.24.17 | SUCCESS | rc=0 >>
GLOBAL:
    SIZE      AVAIL     RAW USED     %RAW USED 
    2039M     1972M       68576k          3.28 
POOLS:
    NAME        ID     USED     %USED     MAX AVAIL     OBJECTS 
    rbd         0         0         0          657M           0 
    images      1         0         0          657M           0 
    volumes     2         0         0          657M           0 
    vms         3         0         0          657M           0 
    backups     4         0         0          657M           0 

 --------- ceph health --------- 
192.168.24.17 | SUCCESS | rc=0 >>
HEALTH_ERR 96 pgs are stuck inactive for more than 300 seconds; 96 pgs degraded; 96 pgs stuck inactive; 96 pgs undersized

 --------- ceph pg stat --------- 
192.168.24.17 | SUCCESS | rc=0 >>
v21: 96 pgs: 96 undersized+degraded+peered; 0 bytes data, 68576 kB used, 1972 MB / 2039 MB avail

[stack@undercloud tripleo-ceph-ansible]$ 
```

### Goal N:

- [Use OS::Mistral::WorflowExecution](https://review.openstack.org/#/c/267770) to start the workflow so all I need to do is `openstack overcloud deploy ...` (Goal2)
- Use [ceph-ansible docker](https://github.com/ceph/ceph-ansible/tree/master/roles/ceph-docker-common) to deploy Ceph in containers [ [done](https://github.com/fultonj/tripleo-ceph-ansible/blob/master/session2.txt) ].
- Use [Containerized Compute](https://access.redhat.com/documentation/en/red-hat-openstack-platform/10/single/advanced-overcloud-customization/#sect-Configuring_Containerized_Compute_Nodes)
- Use [External Ceph](https://access.redhat.com/documentation/en/red-hat-openstack-platform/10/single/red-hat-ceph-storage-for-the-overcloud#integration) to make the overcloud talk to the CephCluster stood up on overcloud nodes without OpenStack services.

Then all I would need to do is insert [Tendrl](https://github.com/tendrl/) in between Mistral and Ceph-Ansible and I would have implemented the main goal of the spec [Integrate TripleO with Tendrl for External Storage Deployment/Management](https://review.openstack.org/#/c/387631).

Assuming the the controller portion of the spec [Deploying TripleO in Containers](https://specs.openstack.org/openstack/tripleo-specs/specs/ocata/containerize-tripleo-overcloud.html)
 is finished, then I could converge them as follows:
 
- ContainerHost{1,2,3}: 2 containers: CephMon and OpenStackController
- ContainerHost{4..N}: 2 containers: NovaCompute and CephOSD

