#!/bin/bash
#
# written by: Dan Bode

set -e
set -u
. local_setup.sh

DIRNAME="/tmp/test-$$"

# preconditions:
# 1. file should not exist
if [ -f $DIRNAME ]; then
  rmdir -f $DIRNAME
fi

# run ralsh to create file
puppet resource file $DIRNAME ensure=directory
# file should have size zero
[ -d $DIRNAME ]
