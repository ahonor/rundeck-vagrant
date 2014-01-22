#!/usr/bin/env bash

# Exit immediately on error or undefined variable.
set -e 
set -u

# Process command line arguments.

# Software install
# ----------------

yum -y install openldap
yum -y install openldap-servers
yum -y install openldap-clients




# set root password
PASS=`slappasswd -s "password"`
cat /vagrant/slapd.conf | sed "s#^rootpw.*\$#rootpw ${PASS}#" > /etc/openldap/slapd.conf

rm -rf /etc/openldap/slapd.d

# Start up openldap
# ----------------

service slapd restart

# load ldif
# -------------

sleep 2

ldapadd -D cn=Manager,dc=example,dc=com -x -w password -f /vagrant/default.ldif

ldapsearch -D cn=Manager,dc=example,dc=com -x -w password -b 'ou=users,dc=example,dc=com' '(cn=*)' *.* 

ldapsearch -D cn=Manager,dc=example,dc=com -x -w password -b 'ou=roles,dc=example,dc=com' '(cn=*)' *.* 

# Done.
exit $?
