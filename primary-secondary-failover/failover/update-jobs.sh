#!/usr/bin/env bash

# Turn cron schedule off for the sync and check jobs
# ----------------------

set -e
set -u



# Process the command arguments.
if [ $# -lt 3 ]
then
    echo >&2 "usage: update-jobs.sh url apikey project"
    exit 1
fi
RDURL=$1
API_KEY=$2
PROJECT=$3



APIURL="${RDURL}/api/1/jobs/export"
AUTHHEADER="X-RunDeck-Auth-Token: $API_KEY"
CURLOPTS="-s -S -L"
CURL="curl $CURLOPTS"
params="project=$PROJECT&groupPath=failover"

echo updating job definition.

# Export the jobs
$CURL -H "$AUTHHEADER" -o jobs.xml $APIURL?${params}
xmlstarlet val -q jobs.xml

# Remove the schedule elements.
xmlstarlet ed -d //job/schedule jobs.xml  > jobs.xml.new


# Import the updated jobs
APIURL="${RDURL}/api/1/jobs/import"
params="dupeOption=update"
$CURL -H "$AUTHHEADER" -o result.xml -F xmlBatch=@jobs.xml.new $APIURL?${params}
success=$(xmlstarlet sel -T -t -v "/result/@success" result.xml)
if [ "true" != "$success" ] ; then
    echo >&2 "FAIL: Server reported an error: "
    xmlstarlet sel -T -t -m "/result/error/message" -v "." -n  result.xml
    exit 2
fi



exit $?
#
# Done.