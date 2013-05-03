#!/usr/bin/env bash


source $(dirname $0)/include.sh

trap 'die $? "*** add-project failed. ***"' ERR
set -o nounset -o pipefail

# Create an example project
rd-project -a create -p example


# Run simple commands to double check.
# Print out the available nodes.
# Fire off a command.
dispatch -p example -v
dispatch -p example -f -- whoami

