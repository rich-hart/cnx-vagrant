# Set up openstax packages

source .profile

cd $DEPLOY_DIR

if [ ! -d openstax-setup ]
then
    git clone https://github.com/$BRANCH/openstax-setup.git
fi
cd openstax-setup

# Set up openstax/accounts
fab -H localhost accounts_setup:https=True

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

fab -H localhost accounts_run_unicorn
fab -H localhost accounts_create_admin_user

# Create an app on accounts
cd ../accounts
. $DEPLOY_DIR/.rvm/scripts/rvm
app_uid_secret=`echo 'app = FactoryGirl.create :doorkeeper_application, :trusted, redirect_uri: "http://'$ipaddr':8080/callback http://'$ipaddr':6544/callback"; puts "#{app.uid}:#{app.secret}"' | bundle exec rails console | tail -3 | head -1`
app_uid=${app_uid_secret/:*/}
app_secret=${app_uid_secret/*:/}
cd ../openstax-setup


