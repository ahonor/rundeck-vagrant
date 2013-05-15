#!/usr/bin/env bash

#set -e 
#set -u

if [ $# -ne 2 ]
then
    echo >&2 "usage: bootstrap name mysqladdr"
    exit 1
fi
NAME=$1
MYSQLADDR=$2

# Software install
# ----------------
#
# Utilities
#
curl -s http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm -o epel-release.rpm -z epel-release.rpm
if ! rpm -q epel-release
then
    rpm -Uvh epel-release.rpm
fi
yum -y install xmlstarlet coreutils rsync
#
# JRE
#
yum -y install java-1.6.0
#
# Rundeck 
#
if ! rpm -q rundeck-repo
then
    rpm -Uvh http://repo.rundeck.org/latest.rpm 
fi
yum -y install rundeck

# Reset the home directory permission as it comes group writeable.
# This is needed for ssh requirements.
chmod 755 ~rundeck

# Configure the system
#
# Add vagrant user to rundeck group
usermod -g rundeck vagrant
#
# Disable the firewall so we can easily access it from the host
service iptables stop
#

# Configure rundeck
# -----------------
# 
cd /etc/rundeck
cat >rundeck-config.properties.new <<EOF
#loglevel.default is the default log level for jobs: ERROR,WARN,INFO,VERBOSE,DEBUG
loglevel.default=INFO
rdeck.base=/var/lib/rundeck
rss.enabled=true
dataSource.url = jdbc:mysql://$MYSQLADDR/rundeck?autoReconnect=true
dataSource.username=rundeckuser
dataSource.password=rundeckpassword
rundeck.clusterMode.enabled=true
EOF
mv rundeck-config.properties.new rundeck-config.properties
chown rundeck:rundeck rundeck-config.properties

sed "s/localhost/$NAME/g" framework.properties > framework.properties.new
grep -q rundeck.server.uuid framework.properties.new || {
UUID=$(uuidgen)
cat >>framework.properties.new <<EOF
rundeck.server.uuid=$UUID
EOF
}
mv framework.properties.new framework.properties
chown rundeck:rundeck framework.properties
#

# Set the rundeck password
# 
echo 'rundeck' | passwd --stdin rundeck

# Start up rundeck
# ----------------
#
mkdir -p /var/log/vagrant
if ! /etc/init.d/rundeckd status
then
    echo "Starting rundeck..."
    (
        exec 0>&- # close stdin
        /etc/init.d/rundeckd start 
    ) &> /var/log/rundeck/service.log # redirect stdout/err to a log.

    let count=0
    let max=18
    while [ $count -le $max ]
    do
        if ! grep  "Started SocketConnector@" /var/log/rundeck/service.log
        then  printf >&2 ".";# progress output.
        else  break; # successful message.
        fi
        let count=$count+1;# increment attempts
        [ $count -eq $max ] && {
            echo >&2 "FAIL: Execeeded max attemps "
            exit 1
        }
        sleep 10
    done
fi

echo "Rundeck started."

exit $?