#!/bin/bash
# run on first monitor node to recreate a ceph-ansible fetch directory
if [[ -d fetch ]]; then
  echo "A directory named fetch already exists. Please rename it."
  exit 1
fi
mkdir fetch
pushd fetch
FSID=$(grep fsid /etc/ceph/ceph.conf | awk {'print $3'})
echo $FSID > ceph_cluster_uuid.conf
mkdir $FSID
pushd $FSID
mkdir -p etc/ceph/
cp /etc/ceph/*.keyring etc/ceph/
mkdir -p var/lib/ceph/
cp -r /var/lib/ceph/bootstrap-* var/lib/ceph/
popd
popd

