#!/bin/bash
#
# written by: Dan Bode

set -e
set -u
. local_setup.sh

DIRNAME="/tmp/test-$$"

# preconditions:
# 1. file should exist
echo $DIRNAME
mkdir -p $DIRNAME
[ -d $DIRNAME ]

# run ralsh to create file
puppet resource file $DIRNAME ensure=absent force=true
# file should not exist
[ ! -d $DIRNAME ]
