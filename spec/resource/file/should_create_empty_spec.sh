#!/bin/bash
#
# written by: Dan Bode

set -e
set -u
. local_setup.sh

FILENAME="/tmp/$0-$$"

# preconditions:
# 1. file should not exist
if [ -f $FILENAME ]; then
  rm -f FILENAME
fi

# run ralsh to create file
puppet resource file $FILENAME ensure=present
# file should have size zero
if [ ! -s $FILENAME ]; then
  exit 0
else 
  echo "file size was non-zero $FILESIZE"
  exit 1
fi
