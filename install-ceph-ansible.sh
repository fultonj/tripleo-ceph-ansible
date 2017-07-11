#!/usr/bin/env bash

# Configure the following repos and install ceph-ansible:
#  http://cbs.centos.org/repos/storage7-ceph-common-candidate/x86_64/os/
#  http://cbs.centos.org/repos/storage7-ceph-jewel-candidate/x86_64/os/

URL=http://cbs.centos.org/repos
SUF=x86_64/os

for repo in storage7-ceph-jewel-release storage7-ceph-common-release; do
    echo "Creating $repo.repo"
    sh -c "cat /dev/null > $repo.repo"
    sh -c "echo \"[$repo]\" >> $repo.repo"
    sh -c "echo \"name=$repo\" >> $repo.repo"
    sh -c "echo \"baseurl=$URL/$repo/$SUF\" >> $repo.repo"
    sh -c "echo \"gpgcheck=0\" >> $repo.repo"
    sh -c "echo \"enabled=1\" >> $repo.repo"
done;

sudo mv *.repo /etc/yum.repos.d/
sudo yum install ceph-ansible -y 
