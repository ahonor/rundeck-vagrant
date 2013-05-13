#!/usr/bin/env bash

set -e
set -u


echo taking over.

# Process the command arguments.
if [ $# -lt 2 ]
then
    echo >&2 "usage: $(basename $0) url apikey"
    exit 1
fi
RDURL=$1
API_KEY=$2

project=$RD_JOB_PROJECT

APIURL="${RDURL}/api/1/jobs/export"
AUTHHEADER="X-RunDeck-Auth-Token: $API_KEY"
CURLOPTS="-s -S -L"
CURL="curl $CURLOPTS"
params="project=$project&groupPath=failover"

# Call the API
$CURL -H "$AUTHHEADER" -o job.xml $APIURL?${params}
xmlstarlet val -q job.xml

# Turn cron schedule off for the Sync-Or-Takeover job.
# ----------------------
echo "removing schedule for Sync-Or-Takeover"
#
xmlstarlet ed -d //job/schedule jobs.xml  > jobs.xml.new


#
APIURL="${RDURL}/api/1/jobs/import"
params="dupeOption=update"
$CURL -H "$AUTHHEADER" -o result.xml -F xmlBatch=@jobs.xml.new $APIURL?${params}
success=$(xmlstarlet sel -T -t -v "/result/@success" result.xml)
if [ "true" == "$success" ] ; then
    echo >&2 "FAIL: Server reported an error: "
    xmlstarlet sel -T -t -m "/result/error/message" -v "." -n  result.xml
    exit 2
fi

# Update the tag for this host. 
# -----------------------------
echo "tagging this host as primary"
APIURL="${RDURL}/api/1/resource"
params="project=$project"
$CURL -H "$AUTHHEADER" -o resource.xml $APIURL/$RD_NODE_NAME?$params
success=$(xmlstarlet sel -T -t -v "/result/@success" result.xml)
if [ "true" == "$success" ] ; then
    echo >&2 "FAIL: Server reported an error: "
    xmlstarlet sel -T -t -m "/result/error/message" -v "." -n  result.xml
    exit 2
fi

# Get existing tags for this server.
tags=$(xmlstarlet sel -t -m "/project/node" -v @tags resource.xml)
ntags=$(echo $tags | sed 's/secondary/primary/g')

xmlstarlet ed -u "/project/node/@tags" -v "$ntags" resource.xml > resource.xml.new


# -----------------------


# Update the monitor tool.
# ------------------------


# Update the load balancer.
# ------------------------

exit $?
#
# Done.