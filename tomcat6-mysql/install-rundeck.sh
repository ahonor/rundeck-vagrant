#!/usr/bin/env bash

# Exit immediately on error or undefined variable.
set -e 
set -u

# Process command line arguments.
if [ $# -ne 4 ]
then
    echo >&2 "usage: $0 rdversion hostname hostip mysqladdr"
    exit 1
fi
RUNDECK_VERSION=$1
HOST_NAME=$2
HOST_IP=$3
MYSQLADDR=$4
export RDECK_BASE=/etc/tomcat6/rundeck

# Software install
# ----------------
#
# Utilities
# Bootstrap a fedora repo to get xmlstarlet

if ! rpm -q epel-release
then
    rpm -Uvh  http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
fi
yum -y install xmlstarlet coreutils rsync unzip
#
# JRE
#
yum -y install java-1.6.0
#
# Tomcat.
#
yum install -y tomcat6 tomcat6-webapps tomcat6-admin-webapps

#
# Rundeck 
#
mkdir -p $RDECK_BASE

## Rundeck WAR
WAR=rundeck-${RUNDECK_VERSION}.war
WAR_URL=http://download.rundeck.org/war/rundeck-${RUNDECK_VERSION}.war
curl -f -s -L $WAR_URL -o ${WAR} -z ${WAR}
mkdir -p /var/lib/tomcat6/webapps/rundeck
unzip -qu ${WAR} -d /var/lib/tomcat6/webapps/rundeck

## Rundeck CLI. Extract the CLI tools from the rundeck-core.jar.
core_jar=/var/lib/tomcat6/webapps/rundeck/WEB-INF/lib/rundeck-core-${RUNDECK_VERSION}.jar
tmp_dir=/tmp/rundeck-core-templates 
mkdir -p $tmp_dir
unzip -qu $core_jar  -d $tmp_dir
mkdir -p $RDECK_BASE/tools/{bin,lib}
mv $tmp_dir/com/dtolabs/rundeck/core/cli/templates/*  $RDECK_BASE/tools/bin
chmod 755 $RDECK_BASE/tools/bin/*
# Copy the CLI libraries.
cp $core_jar  $RDECK_BASE/tools/lib/
libs="ant-*.jar log4j-*.jar commons-codec-*.jar commons-beanutils-*.jar commons-collections-*.jar commons-logging-*.jar commons-lang-*.jar dom4j-*.jar commons-cli-*.jar jsch-*.jar snakeyaml-*.jar xercesImpl-*.jar jaxen-*.jar commons-httpclient-*.jar jdom-*.jar icu4j-*.jar xom-*.jar"
(cd /var/lib/tomcat6/webapps/rundeck/WEB-INF/lib; cp $libs $RDECK_BASE/tools/lib)


#
# Configure Tomcat.
# -------------------

http_port=4440
https_port=4443

# Generate the keystore.
keystore_file=$RDECK_BASE/keystore
keystore_pass=password

if [ ! -f "$keystore_file" ]
then
    keytool -genkey -noprompt \
        -alias     tomcat \
        -keyalg    RSA \
        -dname "CN=rundeck.org, OU=CA, O=RUNDECK, L=Rundeck, S=Rundeck, C=US" \
        -keystore "$keystore_file" \
        -storepass $keystore_pass \
        -keypass   $keystore_pass
    chmod 600 "$keystore_file"
fi

# Configure tomcat to use our ports and keystore.
# Copy existing configuration to a backup file.
if [ -f /etc/tomcat6/server.xml ]
then cp /etc/tomcat6/server.xml /etc/tomcat6/server.xml.$(date +"%Y-%m-%d-%S")
fi
sed -e "s,@http_port@,$http_port,g" \
    -e "s,@https_port@,$https_port,g" \
    -e "s,@keystore_file@,$keystore_file,g" \
    -e "s,@keystore_pass@,$keystore_pass,g" \
    /vagrant/server.xml > /etc/tomcat6/server.xml

# Replace tomcat-users with standard rundeck users and roles
cp /etc/tomcat6/tomcat-users.xml /etc/tomcat6/tomcat-users.xml.$(date +"%Y-%m-%d-%S")
cp /vagrant/tomcat-users.xml /etc/tomcat6/tomcat-users.xml

chkconfig tomcat6 on

# Configure Rundeck.
# ------------------

server_url="https://$HOST_IP:$https_port/rundeck"

if [ ! -f $RDECK_BASE/rundeck-config.properties ]
then
    cat >rundeck-config.properties.new <<EOF
#loglevel.default is the default log level for jobs: ERROR,WARN,INFO,VERBOSE,DEBUG
loglevel.default=INFO
rdeck.base=$RDECK_BASE
rss.enabled=true
dataSource.url = jdbc:mysql://$MYSQLADDR/rundeck?autoReconnect=true
dataSource.username=rundeckuser
dataSource.password=rundeckpassword
EOF
    mv rundeck-config.properties.new $RDECK_BASE/rundeck-config.properties
    chmod 600 $RDECK_BASE/rundeck-config.properties
fi

# Add rundeck configuration location and java startup flags to Tomcat.
if ! grep -q rundeck.config.location /etc/tomcat6/tomcat6.conf 
then
    cat >>  /etc/tomcat6/tomcat6.conf  <<EOF
CATALINA_OPTS="-Drundeck.config.location=$RDECK_BASE/rundeck-config.properties -XX:MaxPermSize=256m -Xmx1024m -Xms256m"
EOF
fi


# Set ownerships to directories Tomcat needs to write.
chown -R tomcat:tomcat /var/log/tomcat6
chown -R tomcat:tomcat $RDECK_BASE

# Start up rundeck
# ----------------

#
# Disable the firewall so we can easily access it from any host.
service iptables stop
#
# Check if rundeck is running and start it if necessary.
# Checks if startup message is contained by log file.
# Fails and exits non-zero if reaches max tries.

set +e; # shouldn't have to turn off errexit.


# Check if tomcat is running and start it if necessary.
# Checks if startup message is contained by log file.
# Fails and exits non-zero if reaches max tries.
if ! service tomcat6 status
then

    success_msg="INFO: Server startup in"
    let count=0
    let max=18

    service tomcat6 start
    while [ $count -le $max ]
    do
        if ! grep "${success_msg}" /var/log/tomcat6/catalina.out
        then  printf >&2 ".";#  output message.
        else  break; # found successful startup message.
        fi
        let count=$count+1;# increment attempts
        [ $count -eq $max ] && {
            echo >&2 "FAIL: Reached max attempts to find success message in log. Exiting."
            exit 1
        }
        sleep 10; # wait 10s before trying again.
    done
fi

echo "Rundeck started."


# Replace references to localhost with this node's name.
sed -e "s#framework.server.port=.*#framework.server.port=$http_port#g" \
    -e "s#framework.rundeck.url=.*#framework.rundeck.url=http://$HOST_NAME:$http_port#g" \
    $RDECK_BASE/etc/framework.properties >framework.properties.new
mv framework.properties.new $RDECK_BASE/etc/framework.properties
echo >&2 "Updated $RDECK_BASE/etc/framework.properties"
egrep 'framework.server.port|framework.rundeck.url' $RDECK_BASE/etc/framework.properties

# Done.
exit $?