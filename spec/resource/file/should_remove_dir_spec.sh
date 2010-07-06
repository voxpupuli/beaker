#!/bin/bash
#
# written by: Dan Bode

set -e
set -u
. local_setup.sh

DIRNAME="/tmp/test-$$"

# preconditions:
# 1. file should exist
if [ ! -d $DIRNAME ]; then
  if [ -e $DIRNAME ]; then
    echo "file already exists and is not a directory"
    exit 1 
  fi
  mkdir FILENAME
fi

# run ralsh to create file
$BIN/puppet resource file $FILENAME ensure=absent
# file should not exist
[ ! -f $FILENAME ]
