#!/usr/bin/env python
# Filename:                extract.py
# Description:             parses desired data from json
# Supported Langauge(s):   Python 2.7.x
# Time-stamp:              <2017-05-25 18:30:33 jfulton> 
# -------------------------------------------------------
# ./extract.py ; cat data.yml | sed s/\'//g
# -------------------------------------------------------
import json
import yaml
import pprint

f='ceph-ansible-input-containers.json'
with open(f) as data_file:
    data = json.load(data_file)

use_values = ["mds_containerized_deployment", "osd_containerized_deployment", "mon_containerized_deployment", "rgw_containerized_deployment", "fetch_directory"]

extra_vars = {}
for key, value in data.iteritems():
    ascii_key = key.encode('ascii', 'ignore')
    if key in use_values:
        try:
            extra_vars[ascii_key] = value.encode('ascii', 'ignore')
        except:
            extra_vars[ascii_key] = value
    elif type(value) is unicode:
        extra_vars[ascii_key] = "\"<% $." + ascii_key + " %>\""
    else:
        extra_vars[ascii_key] = "<% $." + ascii_key + " %>"

#pprint.pprint(extra_vars)

out={'extra_vars': extra_vars}

with open('data.yml', 'w') as outfile:
    yaml.dump(out, outfile, default_flow_style=False)

