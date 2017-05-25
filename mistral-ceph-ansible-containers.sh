#!/usr/bin/env bash
# Filename:                mistral-ceph-ansible-containers.sh
# Description:             ceph-ansible containers w/ mistral
# Time-stamp:              <2017-03-08 18:04:38 jfulton> 
# -------------------------------------------------------
PREP=0
RUN=1
WORKFLOW='mistral-ceph-ansible-containers'
# -------------------------------------------------------
if [[ $PREP -eq 1 ]]; then
    echo "Zapping Disks" # requires inventory
    bash zap.sh
fi
# -------------------------------------------------------
if [[ $RUN -eq 1 ]]; then
    if [[ ! -f ceph-ansible-input-containers.json ]]; then
	echo "Error: ceph-ansible-input-containers.json is not in `pwd`"
	exit 1
    fi
    source ~/stackrc
    EXISTS=$(mistral workflow-list | grep $WORKFLOW | wc -l)
    if [[ $EXISTS -gt 0 ]]; then
	mistral workflow-update $WORKFLOW.yaml
    else
	mistral workflow-create $WORKFLOW.yaml    
    fi
    mistral execution-create $WORKFLOW ceph-ansible-input-containers.json
    UUID=$(mistral execution-list | grep $WORKFLOW | awk {'print $2'} | tail -1)
    mistral execution-get $UUID
    echo "Getting output for the following tasks in workflow $WORKFLOW"
    mistral task-list $UUID
    for TASK_ID in $(mistral task-list $UUID | awk {'print $2'} | egrep -v 'ID|^$'); do
	mistral task-get-result $TASK_ID | jq . | sed -e 's/\\n/\n/g' -e 's/\\"/"/g'
    done

    # to make following up easier:
    echo "UUID: $UUID"
    echo "TASK_ID: $TASK_ID"
    echo $TASK_ID > TASK_ID
fi
