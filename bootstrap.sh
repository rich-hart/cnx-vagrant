#!/usr/bin/env bash

# checklist

# 1. have remote repos set up

# create a .fabricrc file 

# create a .profile file

# a. all ~ are set to the .profile variable DEPLOY

# b. env.cwd = '$DELPOY'

# 2. have script to local download repos

# 3. have script to create vm modify boostrap





# static ip is 10.11.12.13
# we need to setup a fake domain name so google oauth works
ipaddr='dev-vm.cnx.org'

# Add fake domain name to /etc/hosts
sudo sed -i 's/^127.0.0.1 .*/& dev-vm.cnx.org/' /etc/hosts

# Install general packages
sudo apt-get update
sudo apt-get install --yes git python-virtualenv python-dev

# Generate ssh key
if [ ! -d ~/.ssh ]
then
    mkdir ~/.ssh
    chmod 700 ~/.ssh
fi
if [ ! -e ~/.ssh/localhost_id_rsa ]
then
    ssh-keygen -N '' -f ~/.ssh/localhost_id_rsa
    cat ~/.ssh/localhost_id_rsa.pub >>~/.ssh/authorized_keys
    cat >>~/.ssh/config <<EOF

host localhost
identityfile ~/.ssh/localhost_id_rsa
stricthostkeychecking no
EOF
fi

# Set up a smtp server to send emails
wget https://raw.github.com/karenc/cnx-vagrant/master/smtp_server.py
chmod 755 smtp_server.py
sudo ./smtp_server.py &

# generate self-signed ssl certificate for accounts
cd
openssl genrsa -des3 -passout pass:x -out server.pass.key 2048
openssl rsa -passin pass:x -in server.pass.key -out server.key
rm server.pass.key
openssl req -new -key server.key -out server.csr -subj "/c=US/ST=Texas/L=Houston/O=Rice/CN=$ipaddr"
openssl x509 -req -days 365 -in server.csr -signkey server.key -out server.crt

# Set up openstax packages
if [ ! -d openstax-setup ]
then
    git clone https://github.com/karenc/openstax-setup.git
fi
cd openstax-setup
virtualenv .
./bin/pip install fabric

# Set up openstax/accounts
./bin/fab -H localhost accounts_setup:https=True

# Set up facebook and twitter app id and secret
cat >../accounts/config/secret_settings.yml <<EOF
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

./bin/fab -H localhost accounts_run_unicorn
./bin/fab -H localhost accounts_create_admin_user

# Create an app on accounts
cd ../accounts
. ~/.rvm/scripts/rvm
app_uid_secret=`echo 'app = FactoryGirl.create :doorkeeper_application, :trusted, redirect_uri: "http://'$ipaddr':8080/callback http://'$ipaddr':6544/callback"; puts "#{app.uid}:#{app.secret}"' | bundle exec rails console | tail -3 | head -1`
app_uid=${app_uid_secret/:*/}
app_secret=${app_uid_secret/*:/}
cd ../openstax-setup

# Set up cnx packages
cd
if [ ! -d cnx-setup ]
then
    git clone https://github.com/karenc/cnx-setup.git
fi
cd cnx-setup
virtualenv .
./bin/pip install fabric fexpect

# Set up Connexions/cnx-archive
./bin/fab -H localhost archive_setup:https=True
./bin/fab -H localhost archive_run:bg=True

# Set up Connexions/webview
./bin/fab -H localhost webview_setup:https=True

# Link webview to local archive
sed -i "s/devarchive.cnx.org/$ipaddr/" ~/webview/src/scripts/settings.js
sed -i 's/port: 80$/port: 6543/' ~/webview/src/scripts/settings.js
sudo sed -i 's/archive.cnx.org/localhost:6543/' /etc/nginx/sites-available/webview

# Link webview to local accounts
sed -i "s%accountProfile: .*%accountProfile: 'https://$ipaddr:3000/profile',%" ~/webview/src/scripts/settings.js

./bin/fab -H localhost webview_run

# Set up Connexions/cnx-publishing
./bin/fab -H localhost publishing_setup:https=True

# Link publishing to accounts
sed -i 's/openstax_accounts.stub = .*/openstax_accounts.stub = false/' ~/cnx-publishing/development.ini
if [ -z "`grep openstax_accounts.server_url ~/cnx-publishing/development.ini`" ]
then
    sed -i "/openstax_accounts.application_url/ a openstax_accounts.server_url = https://$ipaddr:3000/" ~/cnx-publishing/development.ini
else
    sed -i "s%openstax_accounts.server_url = .*%openstax_accounts.server_url = https://$ipaddr:3000/%" ~/cnx-publishing/development.ini
fi
sed -i "s%openstax_accounts.application_url = .*%openstax_accounts.application_url = http://$ipaddr:6544/%" ~/cnx-publishing/development.ini
if [ -z "`grep openstax_accounts.application_id ~/cnx-publishing/development.ini`" ]
then
    sed -i "/openstax_accounts.application_url/ a openstax_accounts.application_id = $app_uid" ~/cnx-publishing/development.ini
else
    sed -i "s/openstax_accounts.application_id = .*/openstax_accounts.application_id = $app_uid/" ~/cnx-publishing/development.ini
fi
if [ -z "`grep openstax_accounts.application_secret ~/cnx-publishing/development.ini`" ]
then
    sed -i "/openstax_accounts.application_url/ a openstax_accounts.application_secret = $app_secret" ~/cnx-publishing/development.ini
else
    sed -i "s/openstax_accounts.application_secret = .*/openstax_accounts.application_secret = $app_secret/" ~/cnx-publishing/development.ini
fi
# Set up admin as a moderator in publishing
sed -i "/openstax_accounts.groups.moderators/ a\  admin" ~/cnx-publishing/development.ini

# Start publishing on another port, port 6544
sed -i 's/port = 6543/port = 6544/' ~/cnx-publishing/development.ini
./bin/fab -H localhost publishing_run:bg=True

# Set up Connexions/cnx-authoring
./bin/fab -H localhost authoring_setup:https=True
cp ~/cnx-authoring/development.ini.example ~/cnx-authoring/development.ini

# Link authoring to accounts
sed -i 's/openstax_accounts.stub = .*/openstax_accounts.stub = false/' ~/cnx-authoring/development.ini
sed -i "s%^.*openstax_accounts.server_url = .*%openstax_accounts.server_url = https://$ipaddr:3000/%" ~/cnx-authoring/development.ini
sed -i "s%^.*openstax_accounts.application_url = .*%openstax_accounts.application_url = http://$ipaddr:8080/%" ~/cnx-authoring/development.ini
sed -i "s/^.*openstax_accounts.application_id = .*/openstax_accounts.application_id = $app_uid/" ~/cnx-authoring/development.ini
sed -i "s/^.*openstax_accounts.application_secret = .*/openstax_accounts.application_secret = $app_secret/" ~/cnx-authoring/development.ini

# Link authoring to local webview, archive, publishing
sed -i "s%cors.access_control_allow_origin = .*%& http://$ipaddr:8000%" ~/cnx-authoring/development.ini
sed -i "s%webview.url = .*%webview.url = http://$ipaddr:8000/%" ~/cnx-authoring/development.ini
sed -i "s%archive.url = .*%archive.url = http://$ipaddr:6543/%" ~/cnx-authoring/development.ini
sed -i "s%publishing.url = .*%publishing.url = http://$ipaddr:6544/%" ~/cnx-authoring/development.ini

# Set up authoring db after all the changes in development.ini
./bin/fab -H localhost authoring_setup_db

# Start authoring
./bin/fab -H localhost authoring_run:bg=True

# Create a init script so that all the services will start automatically when
# the VM is started
cat <<EOF >/tmp/cnx-dev-vm
#!/bin/sh -e
# cnx-dev-vm
#
# Restart the cnx services

PATH="/bin:/usr/bin"
USER=`echo /home/*/openstax-setup | cut -d '/' -f3`

start_services() {
    cd /home/\$USER/openstax-setup
    sudo -u \$USER ./bin/fab -H localhost accounts_run_unicorn
    sleep 10  # wait for accounts to run
    cd /home/\$USER/cnx-setup
    sudo -u \$USER ./bin/fab -H localhost archive_run:bg=True
    sudo -u \$USER ./bin/fab -H localhost webview_run
    sudo -u \$USER ./bin/fab -H localhost publishing_run:bg=True
    sudo -u \$USER ./bin/fab -H localhost authoring_run:bg=True
    cd /home/\$USER
    sudo /home/\$USER/smtp_server.py &
}

case "\$1" in
start)
    rm /home/\$USER/cnx-archive/paster.pid
    rm /home/\$USER/cnx-publishing/paster.pid
    rm /home/\$USER/cnx-authoring/pyramid.pid
    start_services
    ;;
restart)
    start_services
    ;;
*)
    echo "Usage: /etc/init.d/cnx-dev-vm {start|restart}"
    exit 1
    ;;
esac

exit 0
EOF
sudo mv /tmp/cnx-dev-vm /etc/init.d/
sudo chmod 755 /etc/init.d/cnx-dev-vm
sudo update-rc.d cnx-dev-vm defaults

# Set up ssh keys using the default insecure key
wget https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub
cat vagrant.pub >>~/.ssh/authorized_keys
rm vagrant.pub
