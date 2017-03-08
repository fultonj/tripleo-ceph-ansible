#!/usr/bin/env bash
# Filename:                mistral-ceph-ansible.sh
# Description:             prep and run ceph-ansible
# Time-stamp:              <2017-03-08 17:19:56 jfulton> 
# -------------------------------------------------------
PRE_PREP=0
PREP=1
USE_PLAYBOOKS=0
RUN=1
WORKFLOW='mistral-ceph-ansible'

#OPTION='jeos'
OPTION='hci'
#OPTION='jeos-docker'
#OPTION='hci-docker'
# -------------------------------------------------------
if [[ $PRE_PREP -eq 1 ]]; then
    echo "Updating inventory"
    bash ansible-inventory.sh
    echo "Zapping Disks"
    bash zap.sh
fi
# -------------------------------------------------------
if [[ $PREP -eq 1 ]]; then
    # If we do this for real, then do we ship an RPM of ceph-ansible?
    # It's already shipped for RHCS2 downstream
    if [[ ! -d ceph-ansible ]]; then
	echo "ceph-ansible is missing please run init.sh"
	exit 1
    fi
    if [[ -d /tmp/ceph-ansible ]]; then
	sudo rm -rf /tmp/ceph-ansible
    fi
    cp -r ceph-ansible /tmp/
    sudo chown -R mistral:mistral /tmp/ceph-ansible/
fi
# -------------------------------------------------------
if [[ $USE_PLAYBOOKS -eq 1 ]]; then
    cp /tmp/ceph-ansible/site.yml.sample /tmp/ceph-ansible/site.yml
    
    # all of this nonsense will be-replaced when this workflow is parametized
    if [[ $OPTION == 'jeos' ]]; then
	# need to set mon-interface to eth0
	cp /tmp/ceph-ansible/group_vars/mons.yml.sample /tmp/ceph-ansible/group_vars/mons.yml
	cp group_vars/native-all.yml /tmp/ceph-ansible/group_vars/all.yml
	cp group_vars/osds.yml /tmp/ceph-ansible/group_vars/osds.yml
    fi
    if [[ $OPTION == 'hci' ]]; then
	# need to set mon-interface to br-ex
	cp group_vars/native-all.yml /tmp/ceph-ansible/group_vars/all.yml
	cp group_vars/osds.yml /tmp/ceph-ansible/group_vars/osds.yml
	cp group_vars/mons.yml /tmp/ceph-ansible/group_vars/mons.yml
    fi
    if [[ $OPTION == 'jeos-docker' ]]; then
	# need to set mon-interface to eth0
	# mons.yml is not used in this scenario
	cp group_vars/docker-all.yml /tmp/ceph-ansible/group_vars/all.yml

	# There is an open bug for containerized ceph requring me to update
	#   ceph-ansible/roles/ceph-mon/tasks/docker/pre_requisite.yml
	# 
	# to comment out the following task: 
	# # ensure extras enabled for docker
	# - name: enable extras on centos
	#   yum_repository:
	#     name: extras
	#     state: present
	#     enabled: yes
	#   when:
	#     - ansible_distribution == 'CentOS'
	#   tags:
	#     with_pkg
	# workaround:
	cp ceph-ansible/roles/ceph-mon/tasks/docker/pre_requisite.yml /tmp/ceph-ansible/roles/ceph-mon/tasks/docker/pre_requisite.yml
	
    fi
    if [[ $OPTION == 'hci-docker' ]]; then
	echo "waiting for fix to https://github.com/ceph/ceph-ansible/issues/1321"
	# Items in group_vars/docker-all.yml that don't work with docker are commented out
	# https://github.com/ceph/ceph-ansible/issues/1321
	#cp group_vars/docker-all.yml /tmp/ceph-ansible/group_vars/all.yml
    fi
    #cp group_vars/* /tmp/ceph-ansible/group_vars/
    #rm /tmp/ceph-ansible/group_vars/*-all.yml # don't copy in special exceptions

    sudo chown -R mistral:mistral /tmp/ceph-ansible/
fi
# -------------------------------------------------------
if [[ $RUN -eq 1 ]]; then
    if [[ ! -f ceph-ansible-input.json ]]; then
	echo "Error: ceph-ansible-input.json is not in `pwd`"
	exit 1
    fi
    source ~/stackrc
    EXISTS=$(mistral workflow-list | grep $WORKFLOW | wc -l)
    if [[ $EXISTS -gt 0 ]]; then
	mistral workflow-update $WORKFLOW.yaml
    else
	mistral workflow-create $WORKFLOW.yaml    
    fi
    mistral execution-create $WORKFLOW ceph-ansible-input.json
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
