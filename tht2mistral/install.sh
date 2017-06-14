#!/usr/bin/env bash

target=/home/stack/tripleo-heat-templates
src=/home/stack/tripleo-ceph-ansible/tht2mistral

for dir in $target $src; do 
    if [ ! -d  $dir ]; then 
	echo "$dir is missing; please git clone it"
	exit 1
    fi
done

pushd $target
# ------

echo "Applying https://review.openstack.org/#/c/463324"
cp -v $src/463324/docker/services/services.yaml docker/services/services.yaml
cp -v $src/463324/puppet/services/services.yaml puppet/services/services.yaml

# ------

echo "Applying https://review.openstack.org/#/c/467682/"
cp -v $src/467682/docker/docker-steps.j2 docker/docker-steps.j2
cp -v $src/467682/puppet/post.j2.yaml puppet/post.j2.yaml
cp -v $src/467682/puppet/puppet-steps.j2 puppet/puppet-steps.j2
cp -v $src/467682/network/ports/net_ip_list_map.yaml network/ports/net_ip_list_map.yaml

# This version of overcloud.j2.yaml is from patchset 4, not 6:
#  https://review.openstack.org/#/c/467682/4..6/overcloud.j2.yaml
# The patchet6 version produced the error: 
# CREATE_FAILED  Resource CREATE failed: The Referenced Attribute 
#  (ControllerIpListMap ctlplane_service_ips) is incorrect.
# Workflow using <% env().get('service_ips', {}).get('ceph_mon_node_ips', []) %>
cp -v $src/467682/overcloud.j2.yaml overcloud.j2.yaml

# ------

echo "Applying https://review.openstack.org/#/c/465066"
mkdir -v -p environments/ceph_ansible
cp -v $src/465066/environments/ceph_ansible/ceph_ansible.yaml environments/ceph_ansible/ceph_ansible.yaml

mkdir -v -p extraconfig/ceph_ansible
cp -v $src/465066/extraconfig/ceph_ansible/ceph-base.yaml extraconfig/ceph_ansible/ceph-base.yaml
cp -v $src/465066/extraconfig/ceph_ansible/ceph-mon.yaml extraconfig/ceph_ansible/ceph-mon.yaml
cp -v $src/465066/extraconfig/ceph_ansible/ceph-osd.yaml extraconfig/ceph_ansible/ceph-osd.yaml

# ------
popd
