#!/bin/bash
#
# written by: Dan Bode

set -e
set -u
. local_setup.sh

FILENAME="/tmp/spec-$$-link"
FILENAME2="/tmp/spec-$$-file"

# preconditions:
# 1. file should not exist
if [ -e $FILENAME ]; then
  rm -f $FILENAME
fi
if [ ! -e $FILENAME2 ]; then
  echo hello$$ > $FILENAME2
fi

# run ralsh to create file
puppet resource file $FILENAME ensure=$FILENAME2

# file should have copied the contents
grep hello$$ $FILENAME
