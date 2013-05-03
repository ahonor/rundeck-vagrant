#!/usr/bin/env bash
DEB=http://build.rundeck.org/job/candidate-1.5.1/lastSuccessfulBuild/artifact/packaging/rundeck-1.5.1-1-GA.deb

die() {
   [[ $# -gt 1 ]] && { 
	    exit_status=$1
        shift        
    }
    printf >&2 "ERROR: $*\n"

    exit ${exit_status:-1}
}

#trap 'die $? "*** bootstrap failed. ***"' ERR

set -o nounset -o pipefail

apt-get update
# Install the JRE
apt-get -y install openjdk-6-jre
apt-get -y install curl

# Install Rundeck core

curl -s --fail $DEB -o rundeck.deb 

dpkg -i rundeck.deb
sleep 10

# Start up rundeck
if ! /etc/init.d/rundeckd status
then
    (
        exec 0>&- # close stdin
        /etc/init.d/rundeckd start 
    ) &> /var/log/rundeck/service.log # redirect stdout/err to a log.

    let count=0
    while true
    do
        if ! grep  "Started SocketConnector@" /var/log/rundeck/service.log
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

