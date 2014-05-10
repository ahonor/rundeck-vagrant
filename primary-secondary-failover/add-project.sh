#!/usr/bin/env bash

set -eu


if [[ $# -ne 5 ]]
then
    echo >&2 "usage: add-project project nodename nodeip tags webdav-url"
    exit 1
fi
PROJECT=$1
NODENAME=$2
NODEIP=$3
TAGS=$4
WEBDAV_URL=$5

echo "Create project $PROJECT..."
# Create an example project as the rundeck user
su - rundeck -c "rd-project -a create -p $PROJECT"

# Configure the webdav-logstore plugin.
cat >>/var/rundeck/projects/$PROJECT/etc/project.properties<<EOF
project.plugin.ExecutionFileStorage.webdav-logstore.webdavUrl = $WEBDAV_URL
project.plugin.ExecutionFileStorage.webdav-logstore.webdavUsername = admin
project.plugin.ExecutionFileStorage.webdav-logstore.webdavPassword = admin
EOF

# Run simple commands to double check the project.
su - rundeck -c "dispatch -p $PROJECT" > /dev/null
# Fire off a command.
su - rundeck -c "dispatch -p $PROJECT -f -- whoami"


echo "Project created."


keypath=$(awk -F= '/framework.ssh.keypath/ {print $2}' /etc/rundeck/framework.properties)
echo "ssh-keypath: $keypath"
uuid=$(awk -F= '/rundeck.server.uuid/ {print $2}' /etc/rundeck/framework.properties)
echo "server-uuid: $uuid"

# Update the resource metadata for this host.
DIR=/var/rundeck/projects/$PROJECT/etc

echo "Update resource metadata for this host. (dir=$DIR)"
xmlstarlet ed -u "/project/node/@tags" -v "$TAGS" $DIR/resources.xml  |
xmlstarlet ed -u "/project/node/@name" -v "$NODENAME"                 |  
xmlstarlet ed -u "/project/node/@hostname" -v "$NODEIP"               |  
xmlstarlet ed -i "/project/node" -t attr -n server-uuid -v ${uuid}    |
xmlstarlet ed -i "/project/node" -t attr -n ssh-keypath -v ${keypath} > resources.xml.new
mv resources.xml.new $DIR/resources.xml

# Set the ownerships to rundeck.
chown -R rundeck:rundeck /var/rundeck/projects/$PROJECT


# run the node listing.
echo "List the nodes tagged rundeck:"
su - rundeck -c "dispatch -p $PROJECT -v -I tags=rundeck"


exit $?
