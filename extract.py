#!/usr/bin/env python
# Filename:                extract.py
# Description:             parses desired data from json
# Supported Langauge(s):   Python 2.7.x
# Time-stamp:              <2017-05-25 18:30:33 jfulton> 
# -------------------------------------------------------
import json

f='ceph-ansible-input-containers.json'
with open(f) as data_file:
    data = json.load(data_file)

for key, value in data.iteritems():
    if type(value) is unicode:
        print "\"%s\":\"<%% $.%s %%>\"," % (key, key),
    else:
        print "\"%s\":<%% $.%s %%>," % (key, key),
