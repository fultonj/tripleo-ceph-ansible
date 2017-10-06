# Filename:                get-input.sh
# Description:             extracts --extra-vars from log
# Supported Langauge(s):   GNU Bash 4.x
# Time-stamp:              <2017-10-06 11:23:42 jfulton> 
# -------------------------------------------------------
# fragile script for debugging only to get playbook cmd
# -------------------------------------------------------
log=/var/log/mistral/executor.log
tmp0=/tmp/last-ansible-run0
tmp1=/tmp/last-ansible-run1
tmp2=/tmp/last-ansible-run2
tmp3=/tmp/last-ansible-run3
tmp4=/tmp/last-ansible-run4
tmp5=/tmp/last-ansible-run5
sudo grep site-docker.yml.sample $log | grep ansible-playbook | tail -1 > $tmp0

# split on 'CMD' and take the second half
cat $tmp0 | awk -F  "CMD" '/1/ {print $2}' > $tmp1

# split on 'returned:' and take first half
cat $tmp1 | awk -F  "returned" '/1/ {print $1}' > $tmp2

# remove extra quotes at the beginning and end
cat $tmp2| sed -e s/\"ansible-playbook/ansible-playbook/g -e s/with_pkg\"/with_pkg/g > $tmp3

# remove backslahes 
cat $tmp3 | sed 's/[\]//g' > $tmp4

cat $tmp4

#sec0='AQB0WdZZAAAAABAA4CGrSOjiDsLqYhH4cnhk2g=='
#cat $tmp4 | sed s/monitor_secret.*/monitor_secret\":\ \"$sec0\"/g > $tmp5

#cat $tmp5


# "monitor_secret": "***"
# "rgw_keystone_admin_password": "***"




# "ceph_docker_image_tag": "candidate-88455-20171003204311"
# "ceph_docker_image": "ceph/rhceph-2-rhel7"
# "ceph_docker_registry": "docker-registry.engineering.redhat.com"
