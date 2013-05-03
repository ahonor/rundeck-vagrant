#!/usr/bin/env bash


# The packages
RUNDECK_RPM=http://build.rundeck.org/job/candidate-1.5.1/lastSuccessfulBuild/artifact/packaging/rpmdist/RPMS/noarch/rundeck-1.5.1-1.2.GA.noarch.rpm
RUNDECK_CFG=http://build.rundeck.org/job/candidate-1.5.1/lastSuccessfulBuild/artifact/packaging/rpmdist/RPMS/noarch/rundeck-config-1.5.1-1.2.GA.noarch.rpm

source $(dirname $0)/include.sh


#trap 'die $? "*** bootstrap failed. ***"' ERR

set -o nounset -o pipefail


# Install the JRE via yum
yum -y install java-1.6.0
echo "Java installed."


curl -# --fail $RUNDECK_RPM -o rundeck.rpm -z rundeck.rpm
curl -# --fail $RUNDECK_CFG -o rundeck-cfg.rpm -z rundeck-cfg.rpm

echo "RPM downloaded."


rpm -i rundeck.rpm --nodeps
rpm -i rundeck-cfg.rpm --nodeps

echo "Installed rundeck."


# Disable the firewall so we can easily access it from the host
service iptables stop

# Start up rundeck
if ! /etc/init.d/rundeckd status
then :;
else /etc/init.d/rundeckd stop
fi

echo "Starting rundeck.."
(
    exec 0>&- # close stdin
    /etc/init.d/rundeckd start 
) &> /var/log/rundeck/service.log # redirect stdout/err to the log.

let count=0
while true
do
    if ! grep  "Started SocketConnector@" /var/log/rundeck/service.log
    then  printf >&2 ".";# progress output.
    else  break; # matched success message.
    fi
    let count=$count+1;# increment attempts
    [ $count -eq 18 ] && {
        echo >&2 "FAIL: Execeeded max attemps "
        exit 1
    }
    sleep 10
done


