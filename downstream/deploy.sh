source ~/stackrc
time openstack overcloud deploy --templates \
-r ~/my-templates/roles_data.yaml \
-e /usr/share/openstack-tripleo-heat-templates/environments/docker.yaml \
-e /usr/share/openstack-tripleo-heat-templates/environments/docker-ha.yaml \
-e /usr/share/openstack-tripleo-heat-templates/environments/docker-network.yaml \
-e /usr/share/openstack-tripleo-heat-templates/environments/ceph-ansible/ceph-ansible.yaml \
-e ~/container_images.yaml \
-e ~/my-templates/network.yaml \
-e ~/my-templates/ceph.yaml \
-e ~/my-templates/compute.yaml \
-e ~/my-templates/layout.yaml

#-e /usr/share/openstack-tripleo-heat-templates/environments/ceph-ansible/ceph-mds.yaml \
