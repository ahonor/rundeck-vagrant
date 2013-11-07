#!/usr/bin/env bash

# Exit immediately on error or undefined variable.
set -e
set -u

export RDECK_BASE=/etc/tomcat6/rundeck

echo "Requesting API token..."

RDUSER=$(awk -F= '/framework.server.username/ {print $2}' $RDECK_BASE/etc/framework.properties| tr -d ' ')
RDPASS=$(awk -F= '/framework.server.password/ {print $2}' $RDECK_BASE/etc/framework.properties| tr -d ' ')
SVR_URL=$(awk -F= '/framework.rundeck.url/ {print $2}' $RDECK_BASE/etc/framework.properties|tr -d ' ')


CURLOPTS="-f -s -S -L -c cookies -b cookies"
CURL="curl $CURLOPTS"
    
# Authenticate.
# -------------
# Create session. For tomcat, make a request to get a redirect to the login page. 
$CURL ${SVR_URL} > curl.out; 
# Now post credentials to j_security_check with our cookie session info.
$CURL -X POST -d j_username=$RDUSER -d j_password=$RDPASS "${SVR_URL}/j_security_check" > curl.out

# Request the API token.
# -----------------------
tokenurl="$SVR_URL/user/generateApiToken"
$CURL $tokenurl?login=${RDUSER} > curl.out
xmlstarlet fo -R -H curl.out > userprofile.html 2>/dev/null

# Query the profile for the first apitoken.
# 
token=$(xmlstarlet sel -N x="http://www.w3.org/1999/xhtml" -t -m "//x:span[@class='apitoken']" -v . -n userprofile.html|head -1)

if [ -z "$token" ]
then
    echo >&2 "API token not found in the user profile."
    exit 1
fi
echo "Obtained API token: $token"