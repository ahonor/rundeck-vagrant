#!/usr/bin/env bash

#set -e 
#set -u


# Software install
# ----------------
#
# Utilities
#

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

#
# Disable the firewall so we can easily access it from the host
service iptables stop

#iptables -A INPUT -p tcp --dport 4440 -j ACCEPT
#service iptables save
#

cp /vagrant/jaas-loginmodule.conf /etc/rundeck/jaas-loginmodule.conf

rm /var/lib/rundeck/exp/webapp/WEB-INF/lib/rundeck-jetty-server*.jar 
cp /vagrant/rundeck-jetty-server*.jar /var/lib/rundeck/exp/webapp/WEB-INF/lib


chown rundeck:rundeck /etc/rundeck/jaas-loginmodule.conf
chown rundeck:rundeck /var/lib/rundeck/exp/webapp/WEB-INF/lib/rundeck-jetty-server*.jar 

cat <<END >>/var/lib/rundeck/exp/webapp/WEB-INF/classes/log4j.properties
log4j.logger.com.dtolabs.rundeck.jetty.jaas=DEBUG
END

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
