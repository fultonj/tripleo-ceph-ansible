#!/usr/bin/env bash
# creates env_heat_should_create.json from deployed overcloud's IPs and template
source ~/stackrc
nova list | grep ACTIVE | awk {'print $4,$12'} | sed -e s/ctlplane=//g -e s/overcloud-//g > /tmp/overcloud
IFS=$'\r\n' GLOBIGNORE='*' command eval  'LINE=($(cat /tmp/overcloud))'

cp env_heat_should_create_template.json env_heat_should_create.json
for i in $(seq 0 $(expr $(wc -l /tmp/overcloud | awk {'print $1'}) - 1)); do
    name=$(echo ${LINE[$i]} | awk {'print $1'})
    ip=$(echo ${LINE[$i]} | awk {'print $2'})
    sub=$(echo "s/$name/$ip/g")
    sed -i -e $sub env_heat_should_create.json
done
cat env_heat_should_create.json | jq "."

echo "The above is from the new env_heat_should_create.json"


