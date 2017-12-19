#!/usr/bin/env bash
source ~/stackrc
mistral execution-list | grep SUCCESS | awk {'print $2'} > /tmp/executions
for id in $(cat /tmp/executions); do
    mistral execution-delete $id
done

# Why?
# 'mistral execution-list' onlys shows the first N so 
# the DB fills up and I can't find recently run tasks.

