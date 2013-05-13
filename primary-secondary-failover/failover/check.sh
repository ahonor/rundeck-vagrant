#!/usr/bin/env bash

set -e
set -u

# Call systeminfo API. maxtry=3 timeout(curl /api/systeminfo)

if [ $# -lt 3 ]
then
    echo >&2 "usage: $(basename $0) url apikey maxtry"
    exit 1
fi

RDURL=$1
API_KEY=$2
MAXTRY=$3


APIURL="${RDURL}/api/1/system/info"
AUTHHEADER="X-RunDeck-Auth-Token: $API_KEY"
CURLOPTS="-s -S -L"
CURL="curl $CURLOPTS"

tryagain() {
        max=$1
        : ${cnt:=0} ${max:=3}
        while [ $cnt -le $max ]
        do
            if [ $cnt -eq 3 ]
            then
                echo >&2 "Reached max tries: $max" 
                exit 1
            fi
            cnt=$(expr $cnt + 1)
        done
}

# Submit the request.
trap '{ tryagain $MAXTRY }' ALRM
timeout --signal=ALRM 60 $CURL -H "$AUTHHEADER" -o systeminfo.xml $APIURL

# validate the response is XML
xmlstarlet val -q systeminfo.xml

# Use xml starlet to parse the result.
XML_SEL='xmlstarlet sel -t -m'

# look for error authentication problems.
status=$($XML_SEL "/result" -v @success systeminfo.xml)
if [ "$status" != "true" ]
then
    # print the reason.
    printf "Connection response error. Message: "
    $XML_SEL "/result" -v error systeminfo.xml >&2
    exit $?
fi


# Print out some useful info.
$XML_SEL "/result/success" -o "# " -v message systeminfo.xml
$XML_SEL "/result/system/stats/uptime/since" -o "- up since: " -v datetime systeminfo.xml
$XML_SEL "/result/system/stats/cpu" -o "- cpu avg: " -v loadAverage systeminfo.xml
$XML_SEL "/result/system/stats/memory" -o "- mem free: " -v free systeminfo.xml


exit $?
#
# Done.