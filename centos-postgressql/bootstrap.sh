#!/usr/bin/env bash
set -eu

RDECK_IP=$1

# Install Postgres
#
cat >> /etc/yum.repos.d/CentOS-Base.repo <<EOF
exclude=postgresql*
EOF
yum -y localinstall http://yum.postgresql.org/9.4/redhat/rhel-6-x86_64/pgdg-centos94-9.4-1.noarch.rpm
yum -y install postgresql94-server

service postgresql-9.4 initdb
chkconfig postgresql-9.4 on
service postgresql-9.4 start

# Update configuration
cp /var/lib/pgsql/9.4/data/pg_hba.conf /var/lib/pgsql/9.4/data/pg_hba.conf.orig
grep -v '^local' /var/lib/pgsql/9.4/data/pg_hba.conf |
grep -v '^host' > /var/lib/pgsql/9.4/data/pg_hba.conf.new 

cat >>/var/lib/pgsql/9.4/data/pg_hba.conf.new <<EOF
local   all             all                                     trust
# IPv4 local connections:
host    all             all             127.0.0.1/32            trust
EOF
cp /var/lib/pgsql/9.4/data/pg_hba.conf.new /var/lib/pgsql/9.4/data/pg_hba.conf

# Restart for config take effect
service postgresql-9.4 restart

# Add the rundeck user
cat > /tmp/createdb.sql <<EOF
CREATE ROLE rundeck WITH LOGIN PASSWORD 'rundeck';
CREATE DATABASE rundeck OWNER rundeck;
EOF
chown postgres /tmp/createdb.sql
su - postgres -c "psql -f /tmp/createdb.sql"

#
# Install rundeck
#
yum -y install java-1.7.0

curl -# --fail -L -o /etc/yum.repos.d/rundeck.repo https://bintray.com/rundeck/rundeck-rpm/rpm
rpm -Uvh http://repo.rundeck.org/latest.rpm
yum -y --skip-broken install rundeck

# Configure datasource for postgres db
#
grep -v '^dataSource' /etc/rundeck/rundeck-config.properties  > /etc/rundeck/rundeck-config.properties.new
cat >> /etc/rundeck/rundeck-config.properties  <<EOF
dataSource.driverClassName = org.postgresql.Driver
dataSource.url = jdbc:postgresql://localhost:5432/rundeck
dataSource.username = rundeck
dataSource.password = rundeck
EOF

# Make url acessible 
sed -i -e "s,^grails.serverURL *=.*,grails.serverURL=http://$RDECK_IP:4440,g" \
			/etc/rundeck/rundeck-config.properties
# start
service rundeckd start

# turn off firewalls
service iptables stop

exit $?
