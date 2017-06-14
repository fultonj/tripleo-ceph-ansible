Three patches update THT so it calls Mistral to install ceph-ansible. 
They don't co-exist easily at the moment (need rebase) so install.sh 
will installs them directly in a particular order as a workaround. 

I used to do the following to pull in the following THT changes:
```
    dir=/home/stack/tripleo-heat-templates
    echo "Patching ~/templates with newer unmerged changes from the following:"
    echo "- https://review.openstack.org/#/c/463324"
    echo "- https://review.openstack.org/#/c/467682"
    echo "- https://review.openstack.org/#/c/465066"
    pushd $dir
    # this _should_ pull in 463324 and 467682 via dependencies    
    git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/66/465066/6 && git checkout FETCH_HEAD
    git checkout -b bp/tripleo-ceph-ansible
    popd
```
I found however, that I wouldn't get everything I needed; e.g. I would get 
patchset 4 of overcloud.j2.yaml and not patchset 6: 

 https://review.openstack.org/#/c/467682/4..6/overcloud.j2.yaml

So ctlplane_service_ips was not in the Mistral env() and the deploy failed. 
I think this is becuase 463324 and 467682 have a few of the same files: 
```
./463324/docker/docker-steps.j2
./463324/overcloud.j2.yaml
./463324/puppet/post.j2.yaml
./463324/puppet/puppet-steps.j2

./467682/docker/docker-steps.j2
./467682/overcloud.j2.yaml
./467682/puppet/post.j2.yaml
./467682/puppet/puppet-steps.j2
```
As per the following: 
```
diff -u ./{463324,467682}/docker/docker-steps.j2
diff -u ./{463324,467682}/overcloud.j2.yaml
diff -u ./{463324,467682}/puppet/post.j2.yaml
diff -u ./{463324,467682}/puppet/puppet-steps.j2
```
All of the changes from 467682 are additive for the ctlplane_service_ips. 

Thus, provided I put the files in 467682 after 463324, I will 
overwrite the older files from 463324 to get what I want. I do
not want to skip 463324 altogether as it has changes I need. 

Thus, a script copies the changes in a specific order for now. 
Ultimately, I think these will need to be rebased. 

The install.sh script puts the files in the following order:

 463324, 467682, 465066

It also has the option to install overcloud.j2.yaml from 467682 
as the patcset 4 verson or the patchet 6 version which produce
different enviornments.

Patchset 4:
```
{
  "service_ips": {
    "panko_api_node_ips": [
      "192.168.24.18"
    ],
    "ceph_mon_node_ips": [
      "192.168.24.18"
    ],
    "glance_api_node_ips": [
      "192.168.24.18"
    ],
    "horizon_node_ips": [
      "192.168.24.18"
    ],
    "gnocchi_api_node_ips": [
      "192.168.24.18"
    ],
    "nova_vnc_proxy_node_ips": [
      "192.168.24.18"
    ],
    "heat_api_cfn_node_ips": [
      "192.168.24.18"
    ],
    "nova_placement_node_ips": [
      "192.168.24.18"
    ],
    "nova_libvirt_node_ips": [
      "192.168.24.13"
    ],
    "memcached_node_ips": [
      "192.168.24.18"
    ],
    "nova_metadata_node_ips": [
      "192.168.24.18"
    ],
    "rabbitmq_node_ips": [
      "192.168.24.18"
    ],
    "aodh_api_node_ips": [
      "192.168.24.18"
    ],
    "heat_api_cloudwatch_node_ips": [
      "192.168.24.18"
    ],
    "swift_storage_node_ips": [
      "192.168.24.18"
    ],
    "nova_api_node_ips": [
      "192.168.24.18"
    ],
    "heat_api_node_ips": [
      "192.168.24.18"
    ],
    "cinder_api_node_ips": [
      "192.168.24.18"
    ],
    "redis_node_ips": [
      "192.168.24.18"
    ],
    "keystone_admin_api_node_ips": [
      "192.168.24.18"
    ],
    "keystone_public_api_node_ips": [
      "192.168.24.18"
    ],
    "neutron_api_node_ips": [
      "192.168.24.18"
    ],
    "swift_proxy_node_ips": [
      "192.168.24.18"
    ],
    "mysql_node_ips": [
      "192.168.24.18"
    ]
  },
  "heat_extresource_data": {}
}
```

Patchet 6:
```
{
  "service_ips": {
    "nova_vnc_proxy_ctlplane_node_ips": [
      "192.168.24.18"
    ],
    "timezone_ctlplane_node_ips": [
      "192.168.24.18",
      "192.168.24.13"
    ],
    "aodh_notifier_ctlplane_node_ips": [
      "192.168.24.18"
    ],
    "ca_certs_ctlplane_node_ips": [
      "192.168.24.18",
      "192.168.24.13"
    ],
    "cinder_volume_ctlplane_node_ips": [
      "192.168.24.18"
    ],
    "keystone_ctlplane_node_ips": [
      "192.168.24.18"
    ],
    "aodh_evaluator_ctlplane_node_ips": [
      "192.168.24.18"
    ],
    "swift_storage_ctlplane_node_ips": [
      "192.168.24.18"
    ],
    "redis_ctlplane_node_ips": [
      "192.168.24.18"
    ],
    "nova_scheduler_ctlplane_node_ips": [
      "192.168.24.18"
    ],
    "gnocchi_api_ctlplane_node_ips": [
      "192.168.24.18"
    ],
    "heat_api_cfn_ctlplane_node_ips": [
      "192.168.24.18"
    ],
    "gnocchi_metricd_ctlplane_node_ips": [
      "192.168.24.18"
    ],
    "neutron_dhcp_ctlplane_node_ips": [
      "192.168.24.18"
    ],
    "tripleo_packages_ctlplane_node_ips": [
      "192.168.24.18",
      "192.168.24.13"
    ],
    "nova_conductor_ctlplane_node_ips": [
      "192.168.24.18"
    ],
    "pacemaker_ctlplane_node_ips": [
      "192.168.24.18"
    ],
    "ceph_osd_ctlplane_node_ips": [
      "192.168.24.13"
    ],
    "neutron_plugin_ml2_ctlplane_node_ips": [
      "192.168.24.18",
      "192.168.24.13"
    ],
    "nova_libvirt_ctlplane_node_ips": [
      "192.168.24.13"
    ],
    "cinder_api_ctlplane_node_ips": [
      "192.168.24.18"
    ],
    "swift_proxy_ctlplane_node_ips": [
      "192.168.24.18"
    ],
    "nova_api_ctlplane_node_ips": [
      "192.168.24.18"
    ],
    "heat_api_cloudwatch_ctlplane_node_ips": [
      "192.168.24.18"
    ],
    "ceilometer_expirer_disabled_ctlplane_node_ips": [
      "192.168.24.18"
    ],
    "mysql_ctlplane_node_ips": [
      "192.168.24.18"
    ],
    "glance_api_ctlplane_node_ips": [
      "192.168.24.18"
    ],
    "ceilometer_agent_notification_ctlplane_node_ips": [
      "192.168.24.18"
    ],
    "ntp_ctlplane_node_ips": [
      "192.168.24.18",
      "192.168.24.13"
    ],
    "nova_compute_ctlplane_node_ips": [
      "192.168.24.13"
    ],
    "rabbitmq_ctlplane_node_ips": [
      "192.168.24.18"
    ],
    "mysql_client_ctlplane_node_ips": [
      "192.168.24.18",
      "192.168.24.13"
    ],
    "keystone_public_api_ctlplane_node_ips": [
      "192.168.24.18"
    ],
    "gnocchi_statsd_ctlplane_node_ips": [
      "192.168.24.18"
    ],
    "nova_metadata_ctlplane_node_ips": [
      "192.168.24.18"
    ],
    "tripleo_firewall_ctlplane_node_ips": [
      "192.168.24.18",
      "192.168.24.13"
    ],
    "aodh_listener_ctlplane_node_ips": [
      "192.168.24.18"
    ],
    "neutron_l3_ctlplane_node_ips": [
      "192.168.24.18"
    ],
    "horizon_ctlplane_node_ips": [
      "192.168.24.18"
    ],
    "heat_engine_ctlplane_node_ips": [
      "192.168.24.18"
    ],
    "ceilometer_agent_central_ctlplane_node_ips": [
      "192.168.24.18"
    ],
    "sshd_ctlplane_node_ips": [
      "192.168.24.18",
      "192.168.24.13"
    ],
    "ceph_mon_ctlplane_node_ips": [
      "192.168.24.18"
    ],
    "kernel_ctlplane_node_ips": [
      "192.168.24.18",
      "192.168.24.13"
    ],
    "nova_consoleauth_ctlplane_node_ips": [
      "192.168.24.18"
    ],
    "mongodb_disabled_ctlplane_node_ips": [
      "192.168.24.18"
    ],
    "neutron_metadata_ctlplane_node_ips": [
      "192.168.24.18"
    ],
    "heat_api_ctlplane_node_ips": [
      "192.168.24.18"
    ],
    "memcached_ctlplane_node_ips": [
      "192.168.24.18"
    ],
    "snmp_ctlplane_node_ips": [
      "192.168.24.18",
      "192.168.24.13"
    ],
    "cinder_scheduler_ctlplane_node_ips": [
      "192.168.24.18"
    ],
    "neutron_api_ctlplane_node_ips": [
      "192.168.24.18"
    ],
    "haproxy_ctlplane_node_ips": [
      "192.168.24.18"
    ],
    "keystone_admin_api_ctlplane_node_ips": [
      "192.168.24.18"
    ],
    "ceilometer_agent_compute_ctlplane_node_ips": [
      "192.168.24.13"
    ],
    "swift_ringbuilder_ctlplane_node_ips": [
      "192.168.24.18"
    ],
    "nova_placement_ctlplane_node_ips": [
      "192.168.24.18"
    ],
    "neutron_ovs_agent_ctlplane_node_ips": [
      "192.168.24.18",
      "192.168.24.13"
    ],
    "panko_api_ctlplane_node_ips": [
      "192.168.24.18"
    ],
    "aodh_api_ctlplane_node_ips": [
      "192.168.24.18"
    ]
  },
  "heat_extresource_data": {}
}
```
