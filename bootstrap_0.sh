#!/usr/bin/env bash



DEPLOY_DIR='/opt'

BRANCH=local_install
REMOTE=rich-hart
# static ip is 10.11.12.13
# we need to setup a fake domain name so google oauth works
ipaddr='dev-vm.cnx.org'

# Add fake domain name to /etc/hosts
sed -i 's/^127.0.0.1 .*/& dev-vm.cnx.org/' /etc/hosts

# Install general packages
apt-get update
apt-get install --yes git python-virtualenv python-dev postgresql-9.3 python-pip fabric bundler

pip install -U pip

sudo -u postgres -i createuser -s vagrant
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


# Set up a smtp server to send emails
#cd $DEPLOY_DIR
#wget https://raw.github.com/karenc/cnx-vagrant/master/smtp_server.py
#chmod 755 smtp_server.py
#./smtp_server.py &

cd $DEPLOY_DIR
openssl genrsa -des3 -passout pass:x -out server.pass.key 2048
openssl rsa -passin pass:x -in server.pass.key -out server.key
rm server.pass.key
openssl req -new -key server.key -out server.csr -subj "/c=US/ST=Texas/L=Houston/O=Rice/CN=$ipaddr"
openssl x509 -req -days 365 -in server.csr -signkey server.key -out server.crt



