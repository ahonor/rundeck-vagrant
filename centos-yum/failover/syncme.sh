#!/usr/bin/env bash

set -e
set -u

# Process the command arguments.
if [ $# -lt 2 ]
then
    echo >&2 "usage: $(basename $0) url apikey"
    exit 1
fi
RDURL=$1
API_KEY=$2

project=$RD_JOB_PROJECT

APIURL="${RDURL}/api/3/resources"
AUTHHEADER="X-RunDeck-Auth-Token: $API_KEY"
CURLOPTS="-s -S -L"
CURL="curl $CURLOPTS"
tags="rundeck+primary";  # encode the '+' char.
params="project=$project&tags=${tags/+/%2B}"

# Call the API
$CURL -H "$AUTHHEADER" -o resources.xml $APIURL?${params}
xmlstarlet val -q resources.xml

count=$(xmlstarlet sel -T -t -v "count(/project/node)" resources.xml)
if [ "$count" -ne 1 ]
then
    echo >&2 "Could not locate primary. Count from query result: $count"
    exit 1;
fi

# Lookup primary's hostname and SSH connection details.
SSH_HOST=$(xmlstarlet sel -t -m /project/node -v @hostname    resources.xml)
SSH_USR=$(xmlstarlet  sel -t -m /project/node -v @username    resources.xml)
SSH_KEY=$(xmlstarlet  sel -t -m /project/node -v @ssh-keypath resources.xml)

echo "Will be rsync'ing from primary: $SSH_USR@$SSH_HOST"

# Create backup directories.
BACKUP=/tmp/backup

# List of directories for backup
DIRS=(/var/rundeck/projects /var/lib/rundeck/logs)

SSH_OPTIONS="-oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null"
for dir in ${DIRS[*]}
do
    [ ! -d ${BACKUP}/${dir} ] && mkdir -p ${BACKUP}/${dir}
    rsync -acz --rsh="ssh -i ${SSH_KEY} ${SSH_OPTIONS}" \
        $SSH_USR@$SSH_HOST:$dir  $(dirname ${BACKUP}/${dir})
done


pushd $BACKUP
tar czf /tmp/backup.tzg .
popd

# Copy the primary's data into this instance.
# Use rsync to be efficient about copying changes.

# - Projects
rsync -acz $BACKUP/var/rundeck/projects/* /var/rundeck/projects

# - Execution log output.
rsync -acz $BACKUP/var/lib/rundeck/logs/* /var/lib/rundeck/logs


exit $?
#
# Done.