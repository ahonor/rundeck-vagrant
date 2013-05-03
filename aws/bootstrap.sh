#!/usr/bin/env bash

die() {
   [[ $# -gt 1 ]] && { 
	    exit_status=$1
        shift        
    } 
    local -i frame=0; local info= 
    while info=$(caller $frame)
    do 
        local -a f=( $info )
        [[ $frame -gt 0 ]] && {
            printf >&2 "ERROR in \"%s\" %s:%s\n" "${f[1]}" "${f[2]}" "${f[0]}"
        }
        (( frame++ )) || :; #ignore increment errors (i.e., errexit is set)
    done

    printf >&2 "ERROR: $*\n"

    exit ${exit_status:-1}
}

#trap 'die $? "*** bootstrap failed. ***"' ERR

set -o nounset -o pipefail

apt-get update
# Install the JRE
apt-get -y install openjdk-6-jre

# Install Rundeck core

mkdir -p /var/log/vagrant
curl -sf http://download.rundeck.org/deb/rundeck-1.5-1-GA.deb -o /var/log/vagrant/rundeck-1.5-1-GA.deb 

dpkg -i /var/log/vagrant/rundeck-1.5-1-GA.deb
sleep 10

# Start up rundeck
mkdir -p /var/log/vagrant
if ! /etc/init.d/rundeckd status
then
    (
        exec 0>&- # close stdin
        /etc/init.d/rundeckd start 
    ) &> /var/log/vagrant/bootstrap.log # redirect stdout/err to a log.

    let count=0
    while true
    do
        if ! grep  "Started SocketConnector@" /var/log/vagrant/bootstrap.log
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

