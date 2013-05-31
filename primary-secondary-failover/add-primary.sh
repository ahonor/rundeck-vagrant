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
SSH_HOST_IP=${3}
SSH_HOST_USER=rundeck
SSH_HOST_PASSWD=rundeck

# Lookup the SSH key for this user.
SSH_KEY_PATH_PUB="$(eval echo ~${SSH_HOST_USER}/.ssh/id_rsa.pub)"

if ! eval test -f ${SSH_KEY_PATH_PUB}
then
    echo >&2 "${SSH_HOST_USER} host key not found: $SSH_KEY_PATH_PUB"
    exit 1
fi

SSH_OPTIONS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

# Copy this hosts ssh key to the primary.
if ! timeout 60s su - ${SSH_HOST_USER} -c "ssh ${SSH_OPTIONS} ${SSH_HOST_IP} /bin/true" 2>&1 >/dev/null
then
    echo "Copying secondary's ssh key to ${SSH_HOST_USER}@${SSH_HOST_IP}"
    yum -y install expect

    expect /vagrant/ssh-copy-id.expect ${SSH_HOST_IP} ${SSH_HOST_USER} ${SSH_HOST_PASSWD} ${SSH_KEY_PATH_PUB}

    # Test the key-based ssh access to the primary.
    echo "Testing ssh access..."
    if ! timeout 60s su - ${SSH_HOST_USER} -c "ssh ${SSH_OPTIONS} ${SSH_HOST_USER}@${SSH_HOST_IP} uptime"
    then echo >&2 "Warning. Could not ssh after key was copied. Continuing anyway."
    fi
fi



# Generate the resource metadata for the primary.
RESOURCES=/var/rundeck/projects/${PROJECT}/etc/resources.xml

if ! xmlstarlet sel -t -m "/project/node[@name='${NAME}']" -v @name $RESOURCES
then
    echo "Generating resource info for primary ${SSH_HOST_IP}."
    xmlstarlet ed -P -S -L -s /project -t elem -n NodeTMP -v "" \
        -i //NodeTMP -t attr -n "name" -v "${NAME}" \
        -i //NodeTMP -t attr -n "description" -v "Rundeck server node." \
        -i //NodeTMP -t attr -n "tags" -v "rundeck,primary" \
        -i //NodeTMP -t attr -n "hostname" -v "${SSH_HOST_IP}" \
        -i //NodeTMP -t attr -n "username" -v "${SSH_HOST_USER}" \
        -i //NodeTMP -t attr -n "ssh-keypath" -v "/var/lib/rundeck/.ssh/id_rsa" \
        -r //NodeTMP -v node \
        $RESOURCES
else
    echo "Node $NAME already defined in resources.xml"
fi
chown -R rundeck:rundeck $RESOURCES

# Test the primary can be listed by name or tags.
if [ "$(dispatch -p ${PROJECT} -I name=${NAME})" != ${NAME} ]
then
    echo >&2 "primary node could not be found by name."
    exit 1
fi
if [ "$(dispatch -p ${PROJECT} -I tags=rundeck+primary)" != ${NAME} ]
then
    echo >&2 "primary node could not be found by tags."
    exit 1
fi

exit $?