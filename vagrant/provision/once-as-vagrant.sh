#!/usr/bin/env bash

#== Import script args ==

github_token=$(echo "$1")
domain=$(echo "$2")

#== Bash helpers ==

function info {
  echo " "
  echo "--> $1"
  echo " "
}

#== Provision script ==

info "Provision-script user: `whoami`"

info "Adding GitHub to known hosts"
ssh-keyscan github.com > /home/vagrant/.ssh/known_hosts
echo "Done!"

info "Configure composer"
composer config --global github-oauth.github.com ${github_token}
echo "Done!"

info "Install basic app"
cd /app
composer create-project --prefer-dist --stability=stable yiisoft/yii2-app-basic basic
rm -rf basic/Vagrantfile basic/vagrant README.md .git
shopt -s dotglob
mv basic/* ./
rmdir basic

info "Automatic project dir opening after SSH login"
echo 'cd /app' | tee -a /home/vagrant/.bashrc

info "Enabling colorized prompt for guest console"
sed -i 's/#force_color_prompt=yes/force_color_prompt=yes/' /home/vagrant/.bashrc
echo "Done!"

info "Set server name in nginx config"
sed -i 's/%%domain%%/'"$domain"'/g' ./vagrant/nginx/app.conf