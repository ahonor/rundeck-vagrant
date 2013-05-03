#!/usr/bin/env bash

set -e

source $(dirname $0)/include.sh

# Get the git client installed.
yum -y install git

if [ ! -d rundeck ]
then git clone git://github.com/dtolabs/rundeck.git
else git pull
fi

cd rundeck
bash test/test.sh