#!/usr/bin/env bash
# Filename:                ceph-ansible-logs.sh
# Description:             logs from last ceph-ansible run
# Supported Langauge(s):   GNU Bash 2.4.x w/ TripleO Pike
# Time-stamp:              <2017-11-08 15:17:44 fultonj> 
# -------------------------------------------------------
# grep out the ansible-playbook command
log=/var/log/mistral/executor.log
sudo grep site-docker.yml.sample $log | grep ansible-playbook | grep "mistral.executors.default_executor Command:" | tail -1
# -------------------------------------------------------
# grep out the logs from the playbook run
log=/var/log/mistral/ceph-install-workflow.log
sudo test -e $log
if [[ $? -eq 0 ]]; then
    start_line=$(sudo grep -n "The use of 'include' for tasks has been deprecated." $log | tail -1 | awk {'print $1'} | awk 'BEGIN { FS=":" } { print $1 }')
    end_line=$(sudo wc -l $log | awk {'print $1'})
    this_runs_lines=$(expr $end_line + $start_line)
    sudo tail -n $this_runs_lines $log
else
    echo "ERROR: cannot stat $log"
    exit 1
fi
