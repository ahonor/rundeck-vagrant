#!/usr/bin/env bash

# Exit immediately on error or undefined variable.
set -e 
set -u

# Process command line arguments.

if [ $# -lt 5 ]
then
    echo >&2 "usage: $0 name mysqladdr rundeck_yum_repo rerun_yum_repo webdav_url"
    exit 1
fi
NAME=$1
MYSQLADDR=$2
RUNDECK_REPO_URL=$3
RERUN_REPO_URL=${4}
WEBDAV_URL=${5}

# Software install
# ----------------
#
# Utilities
# Bootstrap a fedora repo to get xmlstarlet

curl -s http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm -o epel-release.rpm -z epel-release.rpm
if ! rpm -q epel-release
then
    rpm -Uvh epel-release.rpm
fi
yum -y install xmlstarlet coreutils rsync

#
# Rerun 
#
if [ -n "${RERUN_REPO_URL:-}" ]
then
    curl -# --fail -L -o /etc/yum.repos.d/rerun.repo "$RERUN_REPO_URL" || {
        echo "failed downloading rerun.repo config"
        exit 2
    }
fi
yum -y install rerun rerun-rundeck-admin

#
# JRE
#
yum -y install java-1.6.0
#
# Rundeck 
#
if [ -n "$RUNDECK_REPO_URL" ]
then
    curl -# --fail -L -o /etc/yum.repos.d/rundeck.repo "$RUNDECK_REPO_URL" || {
        echo "failed downloading rundeck.repo config"
        exit 2
    }
else
    if ! rpm -q rundeck-repo
    then
        rpm -Uvh http://repo.rundeck.org/latest.rpm 
    fi
fi
yum -y --skip-broken install rundeck

# Retreive the webav-logstore file store plugin.
curl -L -s -f -o /var/lib/rundeck/libext/webdav-logstore-plugin.jar \
   "http://dl.bintray.com/ahonor/rundeck-plugins/rundeck-webdav-logstore-plugin-2.1.0.jar"
chown rundeck:rundeck /var/lib/rundeck/libext/webdav-logstore-plugin.jar
mkdir -p /var/lib/rundeck/libext/cache/webdav-logstore-plugin
chown -R rundeck:rundeck /var/lib/rundeck/libext/cache



# Reset the home directory permission as it comes group writeable.
# This is needed for ssh requirements.
chmod 755 ~rundeck
# Add vagrant user to rundeck group.
usermod -g rundeck vagrant

#
# Disable the firewall so we can easily access it from any host.
service iptables stop
#

# Configure rundeck.
# -----------------

# Replace the apitoken policy
cp /vagrant/templates/apitoken.aclpolicy /etc/rundeck/apitoken.aclpolicy

#
# Configure the mysql connection and log file storage plugin.
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
rundeck.execution.logs.fileStoragePlugin=webdav-logstore
EOF
mv rundeck-config.properties.new rundeck-config.properties
chown rundeck:rundeck rundeck-config.properties



# Replace references to localhost with this node's name.
sed "s/localhost/$NAME/g" framework.properties > framework.properties.new
grep -q rundeck.server.uuid framework.properties.new || {
UUID=$(uuidgen)
cat >>framework.properties.new <<EOF
rundeck.server.uuid=$UUID
EOF
}
mv framework.properties.new framework.properties
chown rundeck:rundeck framework.properties

# Set the rundeck password. We need the password set
# to allow us to interactively run ssh-copy-id.
echo 'rundeck' | passwd --stdin rundeck

# Start up rundeck
# ----------------

# Check if rundeck is running and start it if necessary.
# Checks if startup message is contained by log file.
# Fails and exits non-zero if reaches max tries.

set +e; # shouldn't have to turn off errexit.

function wait_for_success_msg {
    success_msg=$1
    let count=0 max=18

    while [ $count -le $max ]
    do
        if ! grep "${success_msg}" /var/log/rundeck/service.log
        then  printf >&2 ".";#  output message.
        else  break; # successful message.
        fi
        let count=$count+1;# increment attempts count.
        [ $count -eq $max ] && {
            echo >&2 "FAIL: Execeeded max attemps "
            exit 1
        }
        sleep 10; # wait 10s before trying again.
    done
}

mkdir -p /var/log/vagrant
success_msg="Connector@"

if ! service rundeckd status
then
    echo "Starting rundeck..."
    (
        exec 0>&- # close stdin
        service rundeckd start 
    ) &> /var/log/rundeck/service.log # redirect stdout/err to a log.

    wait_for_success_msg "$success_msg"

fi

echo "Rundeck started."


# Done.
exit $?
