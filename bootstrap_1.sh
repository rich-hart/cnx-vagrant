#!/usr/bin/env bash



DEPLOY_DIR='/opt'

# static ip is 10.11.12.13
# we need to setup a fake domain name so google oauth works
ipaddr='dev-vm.cnx.org'
#git config --global user.name "rich-hart"
# Add fake domain name to /etc/hosts
sed -i 's/^127.0.0.1 .*/& dev-vm.cnx.org/' /etc/hosts

# Install general packages
apt-get update
apt-get install --yes git python-virtualenv python-dev postgresql-9.3 python-pip fabric

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


# Set up openstax packages
cd $DEPLOY_DIR

if [ ! -d openstax-setup ]
then
    git clone https://github.com/rich-hart/openstax-setup.git
fi
cd $DEPLOY_DIR/openstax-setup

# Set up openstax/accounts
fab -H localhost accounts_setup:https=True

# Set up facebook and twitter app id and secret
cat >$DEPLOY_DIR/accounts/config/secret_settings.yml <<EOF
secret_token: 'Hu7aghaiaiPai2ewAix8OoquNoa1cah4'
smtp_settings:
  address: 'localhost'
  port: 25
# Facebook OAuth API settings
facebook_app_id: '114585082701'
facebook_app_secret: '35b6df2c95b8e3bc7bcd46ce47b1ae02'
# Twitter OAuth API settings
twitter_consumer_key: 'wsSnMNS15nbJRDTqDCDc9IxVs'
twitter_consumer_secret: '78OkKbqZbVSGOZcW7Uv6XyTJWKITepl4TeR7rawjkAsBR5pgZ8'
# Google OAuth API settings
google_client_id: '860946374358-7fvpoadjfpgr2c3d61gca4neatsuhb6a.apps.googleusercontent.com'
google_client_secret: '7gr2AYXrs1GneoVm4mKjG98N'
EOF

cd $DEPLOY_DIR/openstax-setup

fab -H localhost accounts_run_unicorn
fab -H localhost accounts_create_admin_user

# Create an app on accounts
cd $DEPLOY_DIR/accounts
. $DEPLOY_DIR/.rvm/scripts/rvm
app_uid_secret=`echo 'app = FactoryGirl.create :doorkeeper_application, :trusted, redirect_uri: "http://'$ipaddr':8080/callback http://'$ipaddr':6544/callback"; puts "#{app.uid}:#{app.secret}"' | bundle exec rails console | tail -3 | head -1`
app_uid=${app_uid_secret/:*/}
app_secret=${app_uid_secret/*:/}

cd $DEPLOY_DIR/openstax-setup



