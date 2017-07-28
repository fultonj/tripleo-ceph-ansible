#!/usr/bin/env bash
source ~/stackrc
WORKFLOW='tripleo.storage.v1.ceph-install'      # testing from CLI runs? 
#WORKFLOW='tripleo.overcloud.workflowtasks.step2' # testing from Heat runs? 
UUID=$(mistral execution-list | grep $WORKFLOW | awk {'print $2'} | tail -1)
if [ -z $UUID ]; then
    echo "Error: unable to find UUID. Exixting."
    exit 1
fi

for TASK_ID in $(mistral task-list $UUID | grep ceph_install | awk {'print $2'} | egrep -v 'ID|^$'); do
    echo $TASK_ID
    mistral task-get $TASK_ID
    mistral task-get-result $TASK_ID | jq . | sed -e 's/\\n/\n/g' -e 's/\\"/"/g'
done

export UUID
export TASK_ID
