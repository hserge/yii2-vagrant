#!/usr/bin/env bash

#== Import script args ==

timezone=$(echo "$1")
schema_name=$(echo "$2")
db_version=$(echo "$3")
php_version=$(echo "$4")

#== Bash helpers ==

function info {
  echo " "
  echo "--> $1"
  echo " "
}

#== Provision script ==

info "Provision-script user: `whoami`"

export DEBIAN_FRONTEND=noninteractive

info "Configure timezone"
timedatectl set-timezone ${timezone} --no-ask-password
echo "Done!"

info "Add PHP PPA"
add-apt-repository ppa:ondrej/php
echo "Done!"

info "Update OS software"
apt-get update
apt-get upgrade -y
echo "Done!"

info "Install additional software"
apt-get install -y \
"php${php_version}-curl" "php${php_version}-cli" "php${php_version}-intl" "php${php_version}-pgsql" "php${php_version}-gd" "php${php_version}-fpm" "php${php_version}-mbstring" "php${php_version}-xml" php.xdebug \
unzip htop \
nginx

info "Configure PHP"
sed -i 's/display_errors = Off/display_errors = On/g' "/etc/php/${php_version}/fpm/php.ini"
echo "Done!"

info "Configure PHP-FPM"
sed -i 's/user = www-data/user = vagrant/g' "/etc/php/${php_version}/fpm/pool.d/www.conf"
sed -i 's/group = www-data/group = vagrant/g' "/etc/php/${php_version}/fpm/pool.d/www.conf"
sed -i 's/owner = www-data/owner = vagrant/g' "/etc/php/${php_version}/fpm/pool.d/www.conf"

cat << EOF > "/etc/php/${php_version}/mods-available/xdebug.ini"
zend_extension=xdebug.so
xdebug.remote_enable=1
xdebug.remote_connect_back=1
xdebug.remote_port=9000
xdebug.remote_autostart=1
EOF
echo "Done!"

info "Configure NGINX"
sed -i 's/user www-data/user vagrant/g' /etc/nginx/nginx.conf
echo "Done!"

info "Enabling site configuration"
ln -s /app/vagrant/nginx/app.conf /etc/nginx/sites-enabled/app.conf
echo "Done!"

info "Install composer"
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer


info "Install PostgreSQL"
# Edit the following to change the name of the database user that will be created:
APP_DB_GROUP=${schema_name}group
APP_DB_USER=${schema_name}user
APP_DB_ADMIN=${schema_name}admin
APP_DB_ADMIN_PASS=admin
APP_DB_PASS=password

# Edit the following to change the name of the database that is created (defaults to the user name)
APP_DB_NAME=db

# Edit the following to change the version of PostgreSQL that is installed
PG_VERSION=$db_version

###########################################################
# Changes below this line are probably not necessary
###########################################################
print_db_usage () {
  echo "Your PostgreSQL database has been setup and can be accessed on your local machine on the forwarded port (default: 15432)"
  echo "  Host: localhost"
  echo "  Port: 5432"
  echo "  Version: $PG_VERSION"
  echo "  Database: $APP_DB_NAME"
  echo "  Admin User: $APP_DB_ADMIN"
  echo "  Usergroup: $APP_DB_GROUP"
  echo "  Username: $APP_DB_USER"
  echo "  Password: $APP_DB_PASS"
  echo ""
  echo "Admin access to postgres user via VM:"
  echo "  vagrant ssh"
  echo "  sudo su - postgres"
  echo ""
  echo "psql access to app database user via VM:"
  echo "  vagrant ssh"
  echo "  sudo su - postgres"
  echo "  PGUSER=$APP_DB_USER PGPASSWORD=$APP_DB_PASS psql -h localhost $APP_DB_NAME"
  echo ""
  echo "Env variable for application development:"
  echo "  DATABASE_URL=postgresql://$APP_DB_USER:$APP_DB_PASS@localhost:15432/$APP_DB_NAME"
  echo ""
  echo "Local command to access the database via psql:"
  echo "  PGUSER=$APP_DB_USER PGPASSWORD=$APP_DB_PASS psql -h localhost -p 5432 $APP_DB_NAME"
}

export DEBIAN_FRONTEND=noninteractive

PROVISIONED_ON=/etc/vm_provision_on_timestamp
if [ -f "$PROVISIONED_ON" ]
then
  echo "VM was already provisioned at: $(cat $PROVISIONED_ON)"
  echo "To run system updates manually login via 'vagrant ssh' and run 'apt-get update && apt-get upgrade'"
  echo ""
  print_db_usage
  exit
fi

PG_REPO_APT_SOURCE=/etc/apt/sources.list.d/pgdg.list
if [ ! -f "$PG_REPO_APT_SOURCE" ]
then
  # Add PG apt repo:
  echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -c | awk '{print $2}')-pgdg main" > "$PG_REPO_APT_SOURCE"

  # Add PGDG repo key:
  # wget --quiet -Od - https://apt.postgresql.org/pub/repos/apt/ACCC4CF8.asc | apt-key add -
  sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 7FCC7D46ACCC4CF8
  apt-get update
fi

apt-get -y install "postgresql-$PG_VERSION" "postgresql-contrib-$PG_VERSION"

PG_CONF="/etc/postgresql/$PG_VERSION/main/postgresql.conf"
PG_HBA="/etc/postgresql/$PG_VERSION/main/pg_hba.conf"
PG_DIR="/var/lib/postgresql/$PG_VERSION/main"

# Edit postgresql.conf to change listen address to '*':
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" "$PG_CONF"

# Append to pg_hba.conf to add password auth:
echo "host    all             all             all                     md5" >> "$PG_HBA"

# Explicitly set default client_encoding
echo "client_encoding = utf8" >> "$PG_CONF"

# Restart so that all new config is loaded:
service postgresql restart

cat << EOF | su - postgres -c psql

-- create role
CREATE ROLE $APP_DB_GROUP NOLOGIN;
ALTER ROLE $APP_DB_GROUP SET client_encoding TO 'utf8';
-- ALTER ROLE $APP_DB_GROUP SET default_transaction_isolation TO 'read committed';
ALTER ROLE $APP_DB_GROUP SET timezone TO 'UTC';

-- create user
CREATE USER $APP_DB_ADMIN WITH LOGIN PASSWORD '$APP_DB_ADMIN_PASS' SUPERUSER;
CREATE USER $APP_DB_USER WITH LOGIN INHERIT IN ROLE $APP_DB_GROUP PASSWORD '$APP_DB_PASS';
ALTER USER $APP_DB_USER SET search_path TO $schema_name, public;

-- create database (execute separately first and select it or schema will be created in active db)
CREATE DATABASE $APP_DB_NAME WITH OWNER=$APP_DB_USER LC_COLLATE='en_US.utf8' LC_CTYPE='en_US.utf8' ENCODING='UTF-8' TEMPLATE=template0;
-- GRANT ALL PRIVILEGES ON DATABASE $APP_DB_NAME" TO $APP_DB_USER;
\connect $APP_DB_NAME;

-- create schema
CREATE SCHEMA IF NOT EXISTS $schema_name AUTHORIZATION $APP_DB_GROUP;

GRANT ALL PRIVILEGES ON SCHEMA public TO $APP_DB_GROUP;
GRANT ALL PRIVILEGES ON SCHEMA $schema_name TO $APP_DB_GROUP;

-- To set default privileges for future objects, run for every role that creates objects in this schema:
ALTER DEFAULT PRIVILEGES FOR ROLE $APP_DB_USER IN SCHEMA public GRANT ALL ON TABLES TO $APP_DB_GROUP;
ALTER DEFAULT PRIVILEGES FOR ROLE $APP_DB_USER IN SCHEMA public GRANT ALL ON SEQUENCES TO $APP_DB_GROUP;

EOF

# Tag the provision time:
date > "$PROVISIONED_ON"

echo "Successfully created PostgreSQL dev virtual machine."
echo ""
print_db_usage