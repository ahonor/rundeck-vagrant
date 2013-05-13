#!/usr/bin/env bash

set -e
set -u


if [ $# -lt 2 ]
then
    echo >&2 "usage: add-primary project name hostname"
    exit 1
fi
PROJECT=${1}
NAME=${2}
REMOTE_HOST_IP=${3}
REMOTE_HOST_USER=rundeck
REMOTE_HOST_PASSWD=rundeck

SSH_KEY_PATH_PUB="~rundeck/.ssh/id_rsa.pub"


yum -y install expect

# Copy this hosts ssh key to the primary
echo "Copying secondary's ssh key to $REMOTE_HOST_USER@$REMOTE_HOST_IP"
expect -c "expect '' \
  {eval spawn \
  ssh-copy-id -i $SSH_KEY_PATH_PUB $REMOTE_HOST_USER@$REMOTE_HOST_IP; \
  interact -o -nobuffer -re .*assword.* return; \
  send "$REMOTE_HOST_PASSWD\r"; send -- "\r"; \
  expect eof;} "




# Generate the resource metadata for the primary.
DIR=/var/rundeck/projects/$PROJECT/etc
echo "Add primary to resources directory: $DIR"
mkdir -p $DIR/resources
cat >> $DIR/project.properties <<EOF
resources.source.1.type=directory
resources.source.1.config.directory=$DIR/resources
EOF

cat > $DIR/resources/primary.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<project>
  <node name="$NAME" description="The primary rundeck server node."
        tags="rundeck,primary"
        hostname="$REMOTE_HOST_IP"  username="$REMOTE_HOST_USER"
        ssh-keypath="/var/lib/rundeck/.ssh/id_rsa"/>
</project>
EOF

chown -R rundeck:rundeck $DIR/resources

# run the node listing.
dispatch -p $PROJECT -v -I name=$NAME


exit $?