#!/usr/bin/env bash
# Filename:                mistral-ceph-ansible-containers.sh
# Description:             ceph-ansible containers w/ mistral
# Time-stamp:              <2017-03-08 18:04:38 jfulton> 
# -------------------------------------------------------
PREP=0
ENV=0
RUN=1
WORKBOOK=/home/stack/tripleo-common/workbooks/ceph-ansible.yaml
WORKFLOW='tripleo.storage.v1.ceph-install'
source /home/stack/stackrc
# -------------------------------------------------------
if [[ $PREP -eq 1 ]]; then
    echo "Zapping Disks" # requires inventory
    bash zap.sh
fi
# -------------------------------------------------------
if [[ $ENV -eq 1 ]]; then
    ENV=env_heat_should_create
    EXISTS=$(mistral environment-list | grep $ENV | wc -l)
    if [[ $EXISTS -gt 0 ]]; then
        mistral environment-update -f yaml $ENV.json
    else
        mistral environment-create -f yaml $ENV.json
    fi
    mistral environment-get $ENV
fi
# -------------------------------------------------------
if [[ $RUN -eq 1 ]]; then

    if [[ -d /tmp/ceph-ansible-fetch/ ]]; then
	sudo rm -rf /tmp/ceph-ansible-fetch/
    fi
    sudo mkdir /tmp/ceph-ansible-fetch/
    sudo chown mistral:mistral /tmp/ceph-ansible-fetch/

    if [[ ! -f ceph-ansible-input.json ]]; then
	echo "Error: ceph-ansible-input.json is not in `pwd`"
	exit 1
    fi
    if [[ ! -e $WORKBOOK ]]; then
	echo "$WORKBOOK does not exist (see init.sh)"
	exit 1
    fi
    source ~/stackrc
    EXISTS=$(mistral workbook-list | grep tripleo.storage.v1 | wc -l)
    if [[ $EXISTS -gt 0 ]]; then
	mistral workbook-update $WORKBOOK
    else
	mistral workbook-create $WORKBOOK
    fi
    mistral workflow-list | grep $WORKFLOW
    mistral execution-create $WORKFLOW ceph-ansible-input.json '{"env": "env_heat_should_create"}'
    UUID=$(mistral execution-list | grep $WORKFLOW | awk {'print $2'} | tail -1)
    mistral execution-get $UUID
    echo "Getting output for the following tasks in workflow $WORKFLOW"
    mistral task-list $UUID
    for TASK_ID in $(mistral task-list $UUID | awk {'print $2'} | egrep -v 'ID|^$'); do
    	mistral task-get-result $TASK_ID | jq . | sed -e 's/\\n/\n/g' -e 's/\\"/"/g'
    done

    # to make following up easier:
    echo "UUID=$UUID"
    echo "TASK_ID=$TASK_ID"
    echo $TASK_ID > TASK_ID

    # workaround
    sudo rm -rf /tmp/ceph-ansible-fetch/
fi
