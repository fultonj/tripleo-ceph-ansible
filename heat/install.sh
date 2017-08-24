#!/bin/bash

echo "Installing changes to Heat from: https://review.openstack.org/#/c/496216"

diff -u /usr/lib/python2.7/site-packages/heat/objects/resource.py resource.py 
diff -u /usr/lib/python2.7/site-packages/heat/tests/test_stack.py test_stack.py

sudo cp -f resource.py /usr/lib/python2.7/site-packages/heat/objects/resource.py
sudo cp -f test_stack.py /usr/lib/python2.7/site-packages/heat/tests/test_stack.py

sudo systemctl restart openstack-heat-engine
