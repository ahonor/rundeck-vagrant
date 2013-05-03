#!/usr/bin/env bash


# Get the launcher jar
#LAUNCHER_JAR=http://download.rundeck.org/jar/rundeck-launcher-1.5.jar
LAUNCHER_JAR=http://build.rundeck.org/job/candidate-1.5.1/lastSuccessfulBuild/artifact/rundeck-launcher/launcher/build/libs/rundeck-launcher-1.5.1.jar



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


# Install the JRE
yum -y install java-1.6.0
echo "Java installed."
# Install rundeck
export RDECK_BASE=$HOME/rundeck; export RDECK_HOME=$RDECK_BASE
mkdir -p $RDECK_BASE 
echo "Created $RDECK_BASE"

curl -s --fail $LAUNCHER_JAR -o $RDECK_BASE/rundeck-launcher.jar -z $RDECK_BASE/rundeck-launcher.jar
echo "Launcher download."

cd $RDECK_BASE
java -jar ./rundeck-launcher.jar --installonly
echo "Installed rundeck."
java_exe=$(readlink /etc/alternatives/java)
export JAVA_HOME="${java_exe%bin/*}"
$RDECK_BASE/tools/bin/rd-setup -n localhost
echo "Configured rundeck"

# Disable the firewall so we can easily access it from the host
service iptables stop

# Start up rundeck
if ! $RDECK_BASE/server/sbin/rundeckd status
then :;
else $RDECK_BASE/server/sbin/rundeckd stop
fi

echo "Starting rundeck.."
(
    exec 0>&- # close stdin
    $RDECK_BASE/server/sbin/rundeckd start 
) &> $RDECK_BASE/var/log/service.log # redirect stdout/err to the log.

let count=0
while true
do
    if ! grep  "Started SocketConnector@" $RDECK_BASE/var/log/service.log
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


