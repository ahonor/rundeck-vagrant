#!/usr/bin/env bash
set -e 
set -u


# 
# Install the mysql server software
#
yum -y install mysql 
yum -y install mysql-server 
yum -y install mysql-devel 
chgrp -R mysql /var/lib/mysql 
chmod -R 770 /var/lib/mysql 
#
# Startup the server.
service mysqld start 

sleep 20
#
# Create the rundeck database.
mysql --user root --password='' <<EOF
create database rundeck;
grant ALL on rundeck.* to 'rundeckuser'@'%' identified by 'rundeckpassword';
show databases;
quit
EOF

# Shut off the firewall.
service iptables stop