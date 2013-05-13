#!/usr/bin/env bash

set -e
set -u


if [ $# -ne 4 ]
then
    echo >&2 "usage: add-project project nodename nodeip tags"
    exit 1
fi
PROJECT=$1
NODENAME=$2
NODEIP=$3
TAGS=$4


echo Create project $PROJECT...
# Create an example project as the rundeck user
su - rundeck -c "rd-project -a create -p $PROJECT"

# Run simple commands to double check the project.
dispatch -p $PROJECT > /dev/null
# Fire off a command.
dispatch -p $PROJECT -f -- whoami


echo "Project created. Update resource metadata for this host."
keypath=$(awk -F= '/framework.ssh.keypath/ {print $2}' /etc/rundeck/framework.properties)
# Update the resource metadata for this host.
DIR=/var/rundeck/projects/$PROJECT/etc

xmlstarlet ed -u "/project/node/@tags" -v "$TAGS" $DIR/resources.xml  |
xmlstarlet ed -u "/project/node/@name" -v "$NODENAME"                 |  
xmlstarlet ed -u "/project/node/@hostname" -v "$NODEIP"               |  
xmlstarlet ed -i "/project/node" -t attr -n ssh-keypath -v ${keypath} > resources.xml.new
mv resources.xml.new $DIR/resources.xml

# Set the ownerships to rundeck.
chown -R rundeck:rundeck /var/rundeck/projects/$PROJECT


# run the node listing.
echo "List the nodes tagged rundeck:"
dispatch -p $PROJECT -v -I tags=rundeck


exit $?