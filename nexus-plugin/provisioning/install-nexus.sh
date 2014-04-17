#!/bin/bash
set -eu
yum install -y zip unzip curl java7

echo "installing nexus..."

if ! id nexus 
then
   useradd -d /usr/local/nexus -M nexus; echo "created nexus user"
fi

curl -L http://www.sonatype.org/downloads/nexus-latest-bundle.zip -o nexus-latest-bundle.zip

unzip nexus-latest-bundle.zip -d /usr/local
nexus_home=/usr/local/nexus-2*


mkdir -p /usr/local/sonatype-work/nexus/plugin-repository
curl -L https://github.com/downloads/vbehar/nexus-rundeck-plugin/nexus-rundeck-plugin-1.2.2.2-bundle.zip -o nexus-rundeck-plugin.zip
unzip nexus-rundeck-plugin.zip -d /usr/local/sonatype-work/nexus/plugin-repository

ln -s $nexus_home /usr/local/nexus

sed -i 's,NEXUS_HOME=.*,NEXUS_HOME=/usr/local/nexus,g'  /usr/local/nexus/bin/nexus
sed -i 's,#RUN_AS_USER=,RUN_AS_USER=nexus,g'  /usr/local/nexus/bin/nexus
sed -i 's,#PIDDIR=.*,PIDDIR=/usr/local/sonatype-work,g'  /usr/local/nexus/bin/nexus

chown -R nexus $nexus_home /usr/local/sonatype-work
ln -s /usr/local/nexus/bin/nexus /etc/init.d/nexus
chkconfig --add nexus
chkconfig --levels 345 nexus on
service nexus start

service iptables stop


tail /usr/local/nexus/logs/wrapper.log

echo "Login into nexus: admin/admin123"
