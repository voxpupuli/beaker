#!/bin/bash
#
# written by: Dan Bode

set -e
set -u
. local_setup.sh

FILENAME="/tmp/test-$$"

# preconditions:
# 1. file should exist
if [ ! -f $FILENAME ]; then
  touch FILENAME
fi

# run ralsh to create file
puppet resource file $FILENAME ensure=absent
# file should not exist
[ ! -f $FILENAME ]
