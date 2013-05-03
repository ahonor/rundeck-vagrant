#!/usr/bin/env bash

export RDECK_BASE=/root/rundeck; export RDECK_HOME=$RDECK_BASE
PATH=$RDECK_BASE/tools/bin:$PATH
die() {
   [[ $# -gt 1 ]] && { 
	    exit_status=$1
        shift        
    } 
    printf >&2 "ERROR: $*\n"
    exit ${exit_status:-1}
}

trap 'die $? "*** add-project failed. ***"' ERR
set -o nounset -o pipefail

# Create an example project
rd-project -a create -p example


# Run simple commands to double check.
# Print out the available nodes.
# Fire off a command.
dispatch -p example
dispatch -p example -f -- whoami

