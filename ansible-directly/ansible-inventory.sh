#!/bin/bash 
# Filename:                ansible-inventory.sh
# Description:             Builds an Ansible Inventory
# Supported Langauge(s):   GNU Bash 4.2.x
# Time-stamp:              <2016-04-20 13:00:50 jfulton> 
# -------------------------------------------------------
echo "(re)building ansbile inventory"
source ~/stackrc
rm /tmp/client_ips
rm /tmp/osd_ips
rm /tmp/control_ips
for ip in $(nova list | grep cephstorage | awk {'print $12'} | grep ctlplane | sed s/ctlplane=//g); do echo "$ip ansible_ssh_user=heat-admin" >> /tmp/osd_ips; done
for ip in $(nova list | grep compute | awk {'print $12'} | grep ctlplane | sed s/ctlplane=//g); do echo "$ip ansible_ssh_user=heat-admin" >> /tmp/client_ips; done
for ip in $(nova list | grep control | awk {'print $12'} | grep ctlplane | sed s/ctlplane=//g); do echo "$ip ansible_ssh_user=heat-admin" >> /tmp/control_ips; done

sudo sh -c "cat /dev/null > /etc/ansible/hosts"
sudo sh -c "echo \"[mons]\" >> /etc/ansible/hosts"
sudo sh -c "cat /tmp/control_ips >> /etc/ansible/hosts"
sudo sh -c "echo \"\" >> /etc/ansible/hosts"
sudo sh -c "echo \"[osds]\" >> /etc/ansible/hosts"
sudo sh -c "cat /tmp/osd_ips >> /etc/ansible/hosts"
sudo sh -c "echo \"\" >> /etc/ansible/hosts"
sudo sh -c "echo \"[clients]\" >> /etc/ansible/hosts"
sudo sh -c "cat /tmp/client_ips >> /etc/ansible/hosts"
sudo sh -c "echo \"\" >> /etc/ansible/hosts"

ansible mons -m ping
ansible osds -m ping
ansible clients -m ping

echo "Updating ~/.bashrc with \$mon and \$osd variables"
if [[ ! $(grep mons ~/.bashrc) ]]; then 
    echo "mon=\$(grep mons /etc/ansible/hosts -A 1 | tail -1 | awk {'print \$1'})" >> ~/.bashrc
fi

if [[ ! $(grep osds ~/.bashrc) ]]; then 
    echo "osd=\$(grep osds /etc/ansible/hosts -A 1 | tail -1 | awk {'print \$1'})" >> ~/.bashrc
fi

source ~/.bashrc 
