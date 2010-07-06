#!/bin/bash
#
# written by: Dan Bode

set -e
set -u
. local_setup.sh

FILENAME="/tmp/$0-$$-link"
FILENAME2="/tmp/$0-$$-file"

# preconditions:
# 1. file should not exist
if [ -e $FILENAME ]; then
  rm -f FILENAME
fi
if [ ! -e $FILENAME2 ]; then
  touch $FILENAME2
fi

# run ralsh to create file
$BIN/puppet resource file $FILENAME ensure=$FILENAME2
# file should have size zero
[ -L $FILENAME ] && 
