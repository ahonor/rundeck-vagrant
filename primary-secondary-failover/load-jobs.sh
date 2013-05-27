#!/usr/bin/env bash

set -e
set -u

[ $# -lt 1 ] && {
    echo >&2 'usage: load-jobs project [primary]'
    exit 2
}

PROJECT=$1
PRIMARY=${2:-}


echo "Get the API token for this server..."
# GEt the API TOkens 
CURLOPTS="-s -S -L -c cookies -b cookies"
CURL="curl $CURLOPTS"
RDUSER=$(awk -F= '/framework.server.username/ {print $2}' /etc/rundeck/framework.properties| tr -d ' ')
RDPASS=$(awk -F= '/framework.server.password/ {print $2}' /etc/rundeck/framework.properties| tr -d ' ')
SVR_URL=$(awk -F= '/framework.server.url/ {print $2}' /etc/rundeck/framework.properties)

# Authenticate to get the user profile
loginurl="${SVR_URL}/j_security_check"
$CURL $loginurl > curl.out
$CURL -X POST -d j_username=$RDUSER -d j_password=$RDPASS $loginurl > curl.out

# Get the user profile and format the html into well formed xml.
tokenurl="${SVR_URL}/user/profile"
$CURL $tokenurl?login=${RDUSER} > curl.out
xmlstarlet fo -R -H curl.out > user.html 2>/dev/null

# Query the profile for the first apitoken.
# 
token=$(xmlstarlet sel -N x="http://www.w3.org/1999/xhtml" -t -m "//x:span[@class='apitoken']" -v . -n user.html|head -1)
if [ -z "$token" ]
then
    echo >&2 "No API token found in the user profile."
    exit 1
fi

mkdir -p /var/lib/rundeck/scripts/failover
cp /vagrant/failover/*.sh /var/lib/rundeck/scripts/failover
chown -R rundeck:rundeck /var/lib/rundeck/scripts

# Replace the token with the one here.
echo "Updating job definitions for this environment"
sed -e 's,@SCRIPTDIR@,/var/lib/rundeck/scripts/failover,g' /vagrant/jobs/jobs.xml |
xmlstarlet ed -u "//job/context/options/option[@name='key']/@value" -v "$token" |
xmlstarlet ed -u "//job/context/options/option[@name='project']/@value" -v "$PROJECT" |
xmlstarlet ed -u "//job/context/options/option[@name='primary']/@value" -v "${PRIMARY:-}" > jobs.xml.new


# Now load the jobs 
rd-jobs load -f jobs.xml.new
exit $?