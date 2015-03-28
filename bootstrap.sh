#!/usr/bin/env bash

# static ip
ipaddr='10.11.12.13'

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
./bin/fab -H localhost accounts_run_unicorn
./bin/fab -H localhost accounts_create_admin_user

# Create an app on accounts
cd ../accounts
. ~/.rvm/scripts/rvm
app_uid_secret=`echo 'app = FactoryGirl.create :doorkeeper_application, :trusted, redirect_uri: "http://'$ipaddr':8080/callback"; puts "#{app.uid}:#{app.secret}"' | bundle exec rails console | tail -3 | head -1`
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
sed -i "s%accountProfile: .*%accountProfile: 'https://$ipaddr:3000/profile'%" ~/webview/src/scripts/settings.js

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
sed -i "s%openstax_accounts.application_url = .*%openstax_accounts.application_url = http://$ipaddr:8080/%" ~/cnx-publishing/development.ini
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
wget --no-check-certificate https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub
cat vagrant.pub >>~/.ssh/authorized_keys
rm vagrant.pub
