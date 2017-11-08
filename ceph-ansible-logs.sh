#!/usr/bin/env bash
# Filename:                ceph-ansible-logs.sh
# Description:             logs from last ceph-ansible run
# Supported Langauge(s):   GNU Bash 2.4.x w/ TripleO Pike
# Time-stamp:              <2017-11-08 14:56:32 fultonj> 
# -------------------------------------------------------
log=/var/log/mistral/ceph-install-workflow.log
start_line=$(sudo grep -n "The use of 'include' for tasks has been deprecated." $log | tail -1 | awk {'print $1'} | awk 'BEGIN { FS=":" } { print $1 }')
end_line=$(sudo wc -l $log | awk {'print $1'})
this_runs_lines=$(expr $end_line + $start_line)
sudo tail -n $this_runs_lines $log
