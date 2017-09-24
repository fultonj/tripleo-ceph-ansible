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
    echo -e "- No preparation errors found (this script only attempts to help with ceph-disk preparation errors)"
    exit 0
fi

sudo rm -f /tmp/prep_ips /tmp/run_ips /tmp/ips 2> /dev/null
# this may be the list of IPs if there has been this error with only one run...
sudo grep prepare_device /var/log/mistral/ceph-install-workflow.log | grep failed | cut -d ' ' -f 1-8 | awk {'print $7'} | sed -e s/\\[//g -e s/\\]//g | uniq > /tmp/prep_ips

echo -e "- Looking to see if most recent ceph-ansible run failed"
errors=$(sudo tail /var/log/mistral/ceph-install-workflow.log | grep "PLAY RECAP" -A 100 | grep -v "PLAY RECAP" | grep -v failed=0 | wc -l)
if [ $errors -gt 0 ]; then
    echo -e "- The following failures were seen from the last ceph-ansible run: \n"
    sudo tail /var/log/mistral/ceph-install-workflow.log | grep "PLAY RECAP" -A 100 | grep -v "PLAY RECAP" | grep -v failed=0
    echo ""
    sudo tail /var/log/mistral/ceph-install-workflow.log | grep "PLAY RECAP" -A 100 | grep -v "PLAY RECAP" | grep -v failed=0 | awk {'print $6'} | uniq > /tmp/run_ips

    echo -e "- The following hosts had failures from the last ceph-ansible run: \n"
    cat /tmp/run_ips
else
    echo -e "- The last ceph-ansible run did not fail, there might have been ceph-disk preparation erros in the past, but this script cannot help you now."
    exit 0
fi

echo -e "- Assuming you want to fix the OSD nodes that failed last run: \n"
ln -s /tmp/run_ips /tmp/ips

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
