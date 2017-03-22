#!/usr/bin/env bash
source ~/stackrc
WORKFLOW='mistral-ceph-ansible'
UUID=$(mistral execution-list | grep $WORKFLOW | awk {'print $2'} | tail -1)

if [ -z $UUID ]; then
    echo "Error: unable to find UUID. Exixting."
    exit 1
fi

mistral execution-get $UUID
echo "Getting output for the following tasks in workflow $WORKFLOW"
mistral task-list $UUID
for TASK_ID in $(mistral task-list $UUID | awk {'print $2'} | egrep -v 'ID|^$'); do
    mistral task-get $TASK_ID
    mistral task-get-result $TASK_ID | jq . | sed -e 's/\\n/\n/g' -e 's/\\"/"/g'
done
