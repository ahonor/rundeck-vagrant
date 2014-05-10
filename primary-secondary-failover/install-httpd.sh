#!/bin/bash

set -e
set -u

# Software install
# ----------------
#
# Utilities
# Bootstrap a fedora repo to get lighttpd

if ! rpm -q epel-release
then
	rpm -Uvh http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
fi	
yum install -y httpd xmlstarlet

# Apache httpd
# ------------

# Create directory for takeover log messages
mkdir -p /var/www/html/rundeck/takeovers
chown apache:apache /var/www/html/rundeck/takeovers

# Create directory for webdav lock files
mkdir -p /var/lock/apache
chown apache:apache /var/lock/apache

# Create a login for accessing the webdav content.
(echo -n "admin:DAV-upload:" && echo -n "admin:DAV-upload:admin" | 
	md5sum | 
	awk '{print $1}' ) >> /etc/httpd/webdav.passwd

# Generate the configuration into the includes directory.
cat > /etc/httpd/conf.d/webdav.conf<<EOF
DavLockDB /var/lock/apache/DavLock

Alias /dav "/var/www/html/dav"

<Directory /var/www/html/dav>
    Dav On
    Order Allow,Deny
    Allow from all

    AuthType Digest
    AuthName DAV-upload

    # You can use the htdigest program to create the password database:
    #   htdigest -c "/etc/httpd/webdav.passwd" DAV-upload admin
    AuthUserFile "/etc/httpd/webdav.passwd"
    AuthDigestProvider file

    # Allow universal read-access, but writes are restricted
    # to the admin user.
    <LimitExcept GET OPTIONS>
        require user admin
    </LimitExcept>

</Directory>
EOF

# Create subdirectories for webdav content.
mkdir -p /var/www/html/dav
cat > /var/www/html/dav/hi.txt<<EOF
hi, welcome to the WebDAV volume.
EOF
chown -R apache:apache /var/www/html/dav

# Create directories for cgi content.
mkdir -p /var/www/cgi-bin/rundeck
# Copy the cgi scripts
cp /vagrant/failover/*.cgi /var/www/cgi-bin/rundeck
chown -R apache:apache /var/www/cgi-bin/rundeck
chmod +x /var/www/cgi-bin/rundeck/*.cgi

# start the httpd service
service httpd start



# turn off fire wall
service iptables stop
