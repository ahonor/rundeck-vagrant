#!/usr/bin/env bash

# Update the tags for this host. 
# -----------------------------

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

AUTHHEADER="X-RunDeck-Auth-Token: $API_KEY"
CURLOPTS="-s -S -L"
CURL="curl $CURLOPTS"



echo "tagging this host as primary"
APIURL="${RDURL}/api/1/resource"
params="project=$project"
$CURL -H "$AUTHHEADER" -o resource.xml $APIURL/$RD_NODE_NAME?$params
success=$(xmlstarlet sel -T -t -v "/result/@success" result.xml)
if [ "true" != "$success" ] ; then
    echo >&2 "FAIL: Server reported an error: "
    xmlstarlet sel -T -t -m "/result/error/message" -v "." -n  result.xml
    exit 2
fi

# Get existing tags for this server.
tags=$(xml sel -t -m "/project/node" -v @tags resource.xml)
ntags=$(echo $tags | sed 's/secondary/primary/g')

xml ed -u "/project/node/@tags" -v "$ntags" resource.xml > resource.xml.new

exit $?
#
# Done.