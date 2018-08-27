# yii2-vagrant
This is a dev environment based on: Vagrant, php7.2, nginx, PostgreSQL10, yii2-base-app.

This is based on yii2-basic-app vagrant configuration with some changes. The most notable is using PostgreSQL as a 
database server.

Installation
--------------

### Configuration
All configurable parameters are in:
```
vagrant/config/vagrant-local.example.yml
```
Copy that file and name id as vagrant-local.yml then you can customize configuration parameters there. There is no need
to do any other change in provision scripts. They will use configuration parameters during environment setup.

#### PHP
You can change php version in configuration. It should work correctly for 7.x version.

#### PostgreSQL
You can change PostgreSQL version in configuration. It should work correctly for 9.x and 10.x version.
Database name is configurable, but username and password is hard coded, which are:
```
username: localuser
password: password
```
Vagrant also will create port forwarding from host 54321 to guest 5432. 
For external connection (external client for example) use:
```
host: localhost
port: 54321
username: localhost
password: password 
```
#### Yii2
It will checkout yii2-basic-app which is suitable for the most development projects.

### Setup
Just run: 
```
vagrant up
```
It will remove all the traces of current project and wil create a clean `yii2-base-app`.