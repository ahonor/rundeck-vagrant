#!/usr/bin/env bash

set -e
set -u


if [ $# -ne 1 ]
then
    echo >&2 "usage: add-project project"
    exit 1
fi
PROJECT=$1


echo Creating project $PROJECT...
# Create an example project
rd-project -a create -p $PROJECT

# Run simple commands to double check.
dispatch -p $PROJECT
# Run an adhoc command.
dispatch -p $PROJECT -f -- whoami

exit $?