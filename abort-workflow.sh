#!/usr/bin/env bash

source ~/stackrc

EID=$(mistral execution-list | grep -i running  | tail -1 | awk {'print $2'})
echo "mistral execution-update $EID -s ERROR"
mistral execution-update $EID -s ERROR

AEID=$(mistral action-execution-list | grep -i running | tail -1 | awk {'print $2'})
echo "mistral action-execution-update $AEID --state ERROR" 
mistral action-execution-update $AEID --state ERROR 
