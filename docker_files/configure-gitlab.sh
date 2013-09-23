#!/bin/bash

chown git /home/git/.gemrc

# Gitlab-Shell
cd /home/git/gitlab-shell
sudo -u git -H ./bin/install 

# GitLab
cd /home/git/gitlab

# Make sure GitLab can write to the log/ and tmp/ directories
chown -R git log/
chown -R git tmp/
chown -R git config/
chmod -R u+rwX  log/
chmod -R u+rwX  tmp/
chmod o-rwx config/database.yml

# Create directory for satellites
sudo -u git -H mkdir /home/git/gitlab-satellites

# Create directories for sockets/pids and make sure GitLab can write to them
sudo -u git -H mkdir tmp/pids/
sudo -u git -H mkdir tmp/sockets/
sudo chmod -R u+rwX  tmp/pids/
sudo chmod -R u+rwX  tmp/sockets/

# Create public/uploads directory otherwise backup will fail
sudo -u git -H mkdir public/uploads
sudo chmod -R u+rwX  public/uploads

# Configure Git global settings for git user, useful when editing via web
# Edit user.email according to what is set in gitlab.yml
sudo -u git -H git config --global user.name "GitLab"
sudo -u git -H git config --global user.email "gitlab@localhost"
sudo -u git -H git config --global core.autocrlf input

gem install charlock_holmes --version '0.6.9.4'

if [[ $GITLAB_DATABASE = 'mysql' ]]; then
    WITHOUT='postgres'
elif [[ $GITLAB_DATABASE = 'postgresql' ]]; then
    WITHOUT='mysql'
else
    echo "UNKNOWN GITLAB_DATABASE: $GITLAB_DATABASE.  Please read README."
    exit 1
fi

sudo -u git -H bundle install --deployment --without $WITHOUT test aws

sudo -u git -H bundle exec rake gitlab:setup RAILS_ENV=production force=yes