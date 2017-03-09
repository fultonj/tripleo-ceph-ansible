#!/usr/bin/bash

# set -x

IMAGE_DIR="$HOME"
# mkdir -p $IMAGE_DIR
cd $IMAGE_DIR
IMAGE_FILE=overcloud-full.qcow2

[ -x /usr/bin/virt-customize ] || sudo yum install libguestfs-tools -y

# Customize a copy of the image
 if [ ! -f $IMAGE_FILE.orig ]; then
    echo "Saving copy of original $IMAGE_FILE..."
    mv $IMAGE_FILE $IMAGE_FILE.orig
fi
echo "Starting with fresh copy of original $IMAGE_FILE..."
cp $IMAGE_FILE.orig $IMAGE_FILE

echo "Fetching tendrl-tendrl-epel-7.repo..."
curl -Os https://copr.fedorainfracloud.org/coprs/tendrl/tendrl/repo/epel-7/tendrl-tendrl-epel-7.repo

export LIBGUESTFS_BACKEND=direct
echo "Customizing $IMAGE_FILE..."

# Install EPEL in order to install collectd (required by tendrl-node-agent)
# Use yum to install a specific version of tendrl-node-agent)
virt-customize \
    --memsize 2000 \
    --add overcloud-full.qcow2 \
    --run-command "yum -y install http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-9.noarch.rpm" \
    --install collectd \
    --copy-in tendrl-tendrl-epel-7.repo:/etc/yum.repos.d \
    --run-command "yum -y install https://copr-be.cloud.fedoraproject.org/results/tendrl/tendrl/epel-7-x86_64/00524070-python-ruamel-yaml/python2-ruamel-yaml-0.12.14-9.el7.centos.x86_64.rpm" \
    --run-command "yum -y install https://copr-be.cloud.fedoraproject.org/results/tendrl/tendrl-develop/epel-7-x86_64/00523452-maps/maps-4.2.0-2.el7.centos.noarch.rpm" \
    --run-command "yum -y install https://copr-be.cloud.fedoraproject.org/results/tendrl/tendrl-develop/epel-7-x86_64/00524192-tendrl-commons/tendrl-commons-1.2.1-03_09_2017_22_21_11.noarch.rpm" \
    --run-command "yum -y install https://copr-be.cloud.fedoraproject.org/results/tendrl/tendrl-develop/epel-7-x86_64/00524197-tendrl-node-agent/tendrl-node-agent-1.2.1-03_09_2017_22_35_12.noarch.rpm" \
    --run-command "sed -i -e 's/0.0.0.0/192.168.24.253/' /etc/tendrl/node-agent/node-agent.conf.yaml" \
    --run-command "systemctl enable tendrl-node-agent" \
    --selinux-relabel 2>&1 | tee -a $HOME/customize_image.log

packages="collectd,tendrl-node-agent"

# Install tendrl-node-agent from tendrl-tendrl-epel-7.repo
#virt-customize \
#    --memsize 2000 \
#    --add overcloud-full.qcow2 \
#    --copy-in tendrl-tendrl-epel-7.repo:/etc/yum.repos.d \
#    --run-command "yum -y install http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-9.noarch.rpm" \
#    --install $packages \
#    --run-command "sed -i -e 's/0.0.0.0/192.168.24.253/' /etc/tendrl/node-agent/node-agent.conf.yaml" \
#    --run-command "systemctl enable tendrl-node-agent" \
#    --selinux-relabel 2>&1 | tee -a $HOME/customize_image.log

source $HOME/stackrc
echo "Uploading customized $IMAGE_FILE..."
openstack overcloud image upload --update-existing --image-path $IMAGE_DIR
