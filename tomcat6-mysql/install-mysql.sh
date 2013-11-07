#!/usr/bin/env bash

# Exit immediately on error or undefined variable.
set -e 
set -u


# 
# Install software.
# -----------------

#
# Mysql.
#
yum -y install mysql  mysql-server mysql-devel 
chgrp -R mysql /var/lib/mysql 
chmod -R 770 /var/lib/mysql 

# Startup the server.
# ------------------
service mysqld start 

sleep 20; # let it bootup.

#
# Create the database.
# --------------------

# Create the rundeck database and grant access to any host.
mysql --user root --password='' <<EOF
create database rundeck;
grant ALL on rundeck.* to 'rundeckuser'@'%' identified by 'rundeckpassword';
show databases;
quit
EOF

# Shut off the firewall.
service iptables stop

# Done.
exit $?
