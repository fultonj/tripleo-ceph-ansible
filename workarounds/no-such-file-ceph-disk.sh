#!/bin/bash

# workaround for http://tracker.ceph.com/issues/21493

test "$(whoami)" != 'stack' && (echo "This must be run by the stack user on the undercloud"; exit 1)

echo -e "- Looking for evidence of http://tracker.ceph.com/issues/21493"

errors=$(sudo grep prepare_device /var/log/mistral/ceph-install-workflow.log | grep failed | wc -l)
if [ $errors -gt 0 ]; then
    echo -e "- The following from ceph-ansible's output show ceph-disk prepartion errors: \n"
    sudo grep prepare_device /var/log/mistral/ceph-install-workflow.log | grep failed | cut -d ' ' -f 1-8 
    echo ""
else
    echo -e "- No preparation errors found"
    exit 0
fi

sudo grep prepare_device /var/log/mistral/ceph-install-workflow.log | grep failed | cut -d ' ' -f 1-8 | awk {'print $7'} | sed -e s/\\[//g -e s/\\]//g | uniq > /tmp/ips

echo -e "- Will attempt to clean the following nodes for re-run of ceph-disk prepare by ceph-ansible:\n"
cat /tmp/ips
echo ""

function run {
    # run command on host
    ssh $1 -q -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null" -l heat-admin $2
}  

for ip in $(cat /tmp/ips); do 
    echo "- Zapping disks on $ip"
    run $ip "for d in \$(echo /dev/vd{b,c,d}); do sudo sgdisk -Z \$d ; sudo sgdisk -g \$d ; done"
    echo ""
    echo "- Removing all Ceph Docker containers on $ip"
    run $ip "IMAGE=\$(sudo docker images | grep ceph  | awk {'print \$3'}) ; for c in \$(sudo docker ps --all --format \"{{.Names}}\" --filter  ancestor=\$IMAGE); do sudo docker rm \$c; done"
    echo ""
done

echo "Re-run overcloud deployment (or mistral task to run ceph-ansible) and hopefully you will not hit the race bug again (like another roll of the dice)"
