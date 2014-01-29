#!/usr/bin/env bash
set -e
set -u

echo "Generating API token..."

printf "Lookup credentials for login..."
RDUSER=$(awk -F= '/framework.server.username/ {print $2}' /etc/rundeck/framework.properties| tr -d ' ')
RDPASS=$(awk -F= '/framework.server.password/ {print $2}' /etc/rundeck/framework.properties| tr -d ' ')
SVR_URL=$(awk -F= '/framework.server.url/ {print $2}' /etc/rundeck/framework.properties)


CURLOPTS="-f -s -S -L -c cookies -b cookies"
CURL="curl $CURLOPTS"
    
# Authenticate
printf "authenticating..."
loginurl="${SVR_URL}/j_security_check"
$CURL $loginurl > curl.out
$CURL -X POST -d j_username=$RDUSER -d j_password=$RDPASS $loginurl > curl.out

# Generate the API token.
printf "Requesting token..."
tokenurl="$SVR_URL/user/generateApiToken"
$CURL $tokenurl?login=${RDUSER} > curl.out
xmlstarlet fo -R -H curl.out > userprofile.html 2>/dev/null

# Query the profile for the first apitoken.
# 
token=$(xmlstarlet sel -t -m "//span[@class='apitoken']" -v . -n userprofile.html|head -1)

if [ -z "$token" ]
then
    echo >&2 "API token not found in the user profile."
    exit 1
fi
echo "Generated token: $token"
