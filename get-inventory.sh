#!/usr/bin/env bash
source ~/stackrc
WORKFLOW='tripleo.storage.v1.ceph-install'
mistral execution-list | grep $WORKFLOW | awk 'BEGIN { FS="|" } { print $2, $10}' > /tmp/mistral-executions
for UUID in $(cat /tmp/mistral-executions | awk {'print $1'}); do
    date=$(grep $UUID /tmp/mistral-executions | awk {'print $2,$3'})
    echo "Inventory from $date"
    TASK_ID=$(mistral task-list $UUID | grep set_ip_lists | awk {'print $2'})
    mistral task-get-published $TASK_ID    
done
rm /tmp/mistral-executions

