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


AUTHHEADER="X-RunDeck-Auth-Token: $API_KEY"
CURLOPTS="-s -S -L"
CURL="curl $CURLOPTS"
CURL_OUT=$(mktemp "/tmp/curl.out.XXXXX")


# Remove the schedule for the failover jobs
# -----------------------------------------

# Dump the job definitions for the failover job group.

APIURL="${RDURL}/api/1/jobs/export"
params="project=$PROJECT&groupPath=failover"

$CURL -H "$AUTHHEADER" -o jobs.xml $APIURL?${params}
xmlstarlet val -q jobs.xml


# Remove the schedule elements.

xmlstarlet ed -L -d //job/schedule jobs.xml 


# Reload the updated job definitions.

APIURL="${RDURL}/api/1/jobs/import"
params="dupeOption=update"
$CURL -H "$AUTHHEADER" -o $CURL_OUT -F xmlBatch=@jobs.xml $APIURL?${params}

if ! xmlstarlet sel -T -t -v "/result/@success" $CURL_OUT >/dev/null
then
    printf >&2 "FAIL: API error: $APIURL"
    xmlstarlet sel -t -m "/result/error/message" -v "."  $CURL_OUT
    exit 2
fi

echo "Removed schedule for failover jobs."


# Take over scheduled jobs.


# Lookup the primary's server UUID.

APIURL="${RDURL}/api/3/resources"
tags="rundeck+primary";  # encode the '+' char.
params="project=$PROJECT&tags=${tags/+/%2B}"

# Call the resources API
$CURL -H "$AUTHHEADER" -o resources.xml $APIURL?${params}
xmlstarlet val -q resources.xml

count=$(xmlstarlet sel -T -t -v "count(/project/node)" resources.xml)
if [ "$count" -ne 1 ]
then
    echo >&2 "Could not locate primary. Count from query result: $count"
    exit 1;
fi

# Lookup primary's server-uuid and name.
SVR_UUID=$(xmlstarlet sel -t -m /project/node -v @server-uuid    resources.xml)
SVR_NAME=$(xmlstarlet sel -t -m /project/node -v @name    resources.xml)

echo "Taking over scheduled jobs from $SVR_NAME. server-uid: $SVR_UUID..."


# See http://rundeck.org/docs/api/index.html#takeover-schedule-in-cluster-mode
APIURL="${RDURL}/api/7/incubator/jobs/takeoverSchedule"
$CURL -H "$AUTHHEADER" -H "Content-Type: application/xml" -o $CURL_OUT \
    --data "<server uuid=\"${SVR_UUID}\"/>" -X PUT $APIURL

xmlstarlet val -q $CURL_OUT

if ! xmlstarlet sel -T -t -v "/result/@success" $CURL_OUT >/dev/null
then
    printf >&2 "FAIL: API error: $APIURL"
    xmlstarlet sel -t -m "/result/error/message" -v "."  $CURL_OUT
    exit 1
fi

declare -i successful failed
successful=$(xmlstarlet sel -t -m "/result/takeoverSchedule/jobs/successful" -v @count $CURL_OUT)
failed=$(xmlstarlet sel -t -m "/result/takeoverSchedule/jobs/failed" -v @count $CURL_OUT)
if [ "$failed" -ne 0 ]
then
    rerun_die 3 "Not all jobs taken over: $failed out of $((successful+failed))"
else
    echo "Took over schedule for $successful jobs"
fi


exit $?
#
# Done.