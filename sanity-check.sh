#!/usr/bin/env bash

OVERALL=1
CINDER=0
GLANCE=0

source /home/stack/stackrc

# all my inventories are dynamic; this is a workaround to keep it that way
mon=$(nova list | grep controller | awk {'print $12'} | sed s/ctlplane=//g)

source /home/stack/tripleo-ceph-ansible/overcloudrc
if [ $OVERALL -eq 1 ]; then   
    echo " --------- ceph -s --------- "
    ansible all -i $mon, -u heat-admin  -b -m shell -a "ceph -s"
    echo " --------- ceph df --------- "
    ansible all -i $mon, -u heat-admin  -b -m shell -a "ceph df"
fi

if [ $CINDER -eq 1 ]; then
    echo " --------- Ceph cinder volumes pool --------- "
    ansible all -i $mon, -u heat-admin  -b -m shell -a "rbd -p volumes ls -l"
    openstack volume list

    echo "Creating 20G Cinder volume"
    openstack volume create --size 20 test-volume
    sleep 30 

    echo "Listing Cinder Ceph Pool and Volume List"
    openstack volume list
    ansible all -i $mon, -u heat-admin  -b -m shell -a "rbd -p volumes ls -l"
fi

if [ $GLANCE -eq 1 ]; then
    img=cirros-0.3.4-x86_64-disk.img
    raw=$(echo $img | sed s/img/raw/g)
    url=http://download.cirros-cloud.net/0.3.4/$img
    if [ ! -f $raw ]; then
	if [ ! -f $img ]; then
	    echo "Could not find qemu image $img; downloading a copy."
	    curl -# $url > $img
	fi
	echo "Could not find raw image $raw; converting."
	qemu-img convert -f qcow2 -O raw $img $raw
    fi

    echo " --------- Ceph images pool --------- "
    echo "Listing Glance Ceph Pool and Image List"
    ansible all -i $mon, -u heat-admin  -b -m shell -a "rbd -p images ls -l"
    openstack image list

    echo "Importing $raw image into Glance"
    openstack image create cirros --disk-format=raw --container-format=bare < $raw
    if [ ! $? -eq 0 ]; then 
        echo "Could not import $raw image. Aborting"; 
        exit 1;
    fi

    echo "Listing Glance Ceph Pool and Image List"
    ansible all -i $mon, -u heat-admin  -b -m shell -a "rbd -p images ls -l"
    openstack image list
fi
