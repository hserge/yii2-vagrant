#!/usr/bin/env bash

#== Import script args ==

php_version=$(echo "$1")

#== Bash helpers ==

function info {
  echo " "
  echo "--> $1"
  echo " "
}

#== Provision script ==

info "Provision-script user: `whoami`"

info "Restart web-stack"
service "php${php_version}-fpm" restart
service nginx restart
service postgresql restart
