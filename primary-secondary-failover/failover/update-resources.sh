#!/usr/bin/env bash

# Update the tags for this host. 
# -----------------------------

set -e
set -u


# Process the command arguments.
if [ $# -lt 4 ]
then
    echo >&2 "usage: $(basename $0) url apikey project node"
    exit 1
fi
RDURL=$1
API_KEY=$2
PROJECT=$3
NODE=$4



AUTHHEADER="X-RunDeck-Auth-Token: $API_KEY"
CURLOPTS="-s -S -L"
CURL="curl $CURLOPTS"

CURL_OUT=$(mktemp "/tmp/update-resources.sh.curl.out.XXXXX")
RESOURCES=$(mktemp "/tmp/update-resources.sh.resources.xml.XXXXX")

echo "tagging this host as primary."

# List the resources.
# -------------------

# Search for the current primary node.

APIURL="${RDURL}/api/3/resources"
AUTHHEADER="X-RunDeck-Auth-Token: $API_KEY"
qtags="rundeck+primary";  # encode the '+' char.
params="project=$PROJECT&tags=${qtags/+/%2B}"

$CURL -H "$AUTHHEADER" -o $CURL_OUT $APIURL?${params}
xmlstarlet val -q $CURL_OUT

# List the primaries.
PRIMARIES=( $(xmlstarlet sel -t -m "/project/node" -v @name $CURL_OUT) )

# List all the resources.
APIURL="${RDURL}/api/3/project/${PROJECT}/resources"
$CURL -H "$AUTHHEADER" -o $CURL_OUT $APIURL

# Remove the primary tag from any nodes tagged as such.
for nodename in ${PRIMARIES[*]}
do
    otags=$(xmlstarlet sel -t -m "/project/node[@name='$nodename']" -v @tags $CURL_OUT)
    ntags=$(echo $otags | sed 's/primary//g')
    # Use -L to edit the resources file in place.
    xmlstarlet ed -L -u "/project/node[@name='${nodename}']/@tags" -v "$ntags" $CURL_OUT 
    echo >&2 "Removed tag: primary, from node: $nodename"
done

# Read the tags for the secondary rundeck.
tags=$(xmlstarlet sel -t -m "/project/node[@name='${NODE}']" -v @tags $CURL_OUT)
stags=$(echo $tags | sed 's/secondary/primary/g')


# Update the resources.
# ---------------------

# Rewrite the tags for the two rundecks.
xmlstarlet ed -u "/project/node[@name='${NODE}']/@tags" -v "$stags" $CURL_OUT > $RESOURCES

# Post the updated resources.xml back to the secondary rundeck.
$CURL -X POST -H "$AUTHHEADER" -H "Content-Type: text/xml" -d @$RESOURCES -o $CURL_OUT $APIURL

success=$(xmlstarlet sel -T -t -v "/result/@success" $CURL_OUT)
if [ "true" != "$success" ] ; then
    echo >&2 "FAIL: Server reported an error: "
    xmlstarlet sel -T -t -m "/result/error/message" -v "." -n  $CURL_OUT
    exit 2
fi


exit $?
#
# Done.