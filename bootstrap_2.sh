#!/usr/bin/env bash



DEPLOY_DIR='/opt'

# static ip is 10.11.12.13
# we need to setup a fake domain name so google oauth works
ipaddr='dev-vm.cnx.org'

# Add fake domain name to /etc/hosts
sed -i 's/^127.0.0.1 .*/& dev-vm.cnx.org/' /etc/hosts

# Install general packages
apt-get update
apt-get install --yes git python-virtualenv python-dev

# Generate ssh key
if [ ! -d $DEPLOY_DIR/.ssh ]
then
    mkdir $DEPLOY_DIR/.ssh
    chmod 700 $DEPLOY_DIR/.ssh
fi

if [ ! -e $DEPLOY_DIR/.ssh/localhost_id_rsa ]
then
    ssh-keygen -N '' -f $DEPLOY_DIR/.ssh/localhost_id_rsa
    cat $DEPLOY_DIR/.ssh/localhost_id_rsa.pub >>$DEPLOY_DIR/.ssh/authorized_keys
    cat >>$DEPLOY_DIR/.ssh/config <<EOF
host localhost
identityfile $DEPLOY_DIR/.ssh/localhost_id_rsa
stricthostkeychecking no
EOF
fi

