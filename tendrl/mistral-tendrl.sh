#!/usr/bin/env bash
# Filename:                mistral-tendrl.sh
# Description:             run tendrl via mistral
# Time-stamp:              <2017-03-08 12:08:13 jfulton> 
# -------------------------------------------------------
KEY=1
PREP=0
RUN=1
WORKFLOW='mistral-tendrl'
# -------------------------------------------------------
if [[ $KEY -eq 1 ]]; then
    # keyring hack that works on our 6 dev systems
    host=$(ssh 192.168.23.1 -l root "hostname")
    declare -A KEYMAP
    KEYMAP[tendrl-ooo.cloud.lab.eng.bos.redhat.com]="da86217227df33432028da2fbcbc5dc8359d085866c5f39f95e01006e2535416"
    KEYMAP[tendrl1.cloud.lab.eng.bos.redhat.com]="fec11ad9d634e9efe402463ba28b9c9baac852122f533f750ed12be03c803c44"
    KEYMAP[tendrl2.cloud.lab.eng.bos.redhat.com]="bd7bd0df9bd9d9916c8728f7743175c14d1c7240c5e69ff3ba6363671736b455"
    KEYMAP[tendrl3.cloud.lab.eng.bos.redhat.com]="b87d7c4eddaa4c6fa41591a2a7dd1c04265d7591cbabc76ae7819cd982436531"
    KEYMAP[jefbrown-sim-machine.desklab.eng.bos.redhat.com]="a84468bc2303b710e4f444d609be958c68b8e316124e07ce5c37663a67e802bb"
    KEYMAP[beast.usersys.redhat.com]="7dae3d782c337c7a4c9ffd4fcad0632ce7076817327795f7404c4009207cb7a8"
    key=${KEYMAP[$host]}
    cat /dev/null > tendrl-input.json
    echo "{" >> tendrl-input.json
    echo "\"key\": \"$key\"" >> tendrl-input.json
    echo "}" >> tendrl-input.json
fi
# -------------------------------------------------------
if [[ $PREP -eq 1 ]]; then
    echo "Zapping Disks"
    bash zap.sh
fi
# -------------------------------------------------------
if [[ $RUN -eq 1 ]]; then
    source ~/stackrc
    EXISTS=$(mistral workflow-list | grep $WORKFLOW | wc -l)
    if [[ $EXISTS -gt 0 ]]; then
	mistral workflow-update $WORKFLOW.yaml
    else
	mistral workflow-create $WORKFLOW.yaml    
    fi
    mistral execution-create $WORKFLOW tendrl-input.json
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
