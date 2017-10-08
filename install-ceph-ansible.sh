#!/usr/bin/env bash

# Configure the following repos and install ceph-ansible:
#  http://cbs.centos.org/repos/storage7-ceph-common-candidate/x86_64/os/
#  http://cbs.centos.org/repos/storage7-ceph-jewel-candidate/x86_64/os/

URL=http://cbs.centos.org/repos
SUF=x86_64/os

# https://cbs.centos.org/koji/taginfo?tagID=737
VERSION=candidate

# https://cbs.centos.org/koji/taginfo?tagID=738
#VERSION=testing

# https://cbs.centos.org/koji/taginfo?tagID=739
#VERSION=release

for repo in storage7-ceph-jewel-$VERSION storage7-ceph-common-$VERSION; do
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
