#!/usr/bin/env bash

set -o nounset -o pipefail

DEB_REPO_URL=$1

# setup bintray debian repo
echo "deb $DEB_REPO_URL /" >> /etc/apt/sources.list 
echo "deb-src $DEB_REPO_URL /" >> /etc/apt/sources.list

apt-get update

# Install the JRE
apt-get -y install openjdk-7-jre
apt-get -y install curl


# Install Rundeck 
apt-get -y --force-yes install rundeck

sleep 10

# Start up rundeck
if ! $( status rundeckd | grep -q running )
then
    start rundeckd

    let count=0
    while true
    do
        if ! grep  "Started SelectChannelConnector@" /var/log/rundeck/service.log
        then  printf >&2 ".";# progress output.
        else  break; # successful message.
        fi
        let count=$count+1;# increment attempts
        [ $count -eq 18 ] && {
            echo >&2 "FAIL: Execeeded max attemps "
            exit 1
        }
        sleep 10
    done
fi

