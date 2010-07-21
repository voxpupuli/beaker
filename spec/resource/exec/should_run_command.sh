#!/bin/bash
# 
# description: tests that puppet correctly runs an exec.
# author: Dan Bode
set -e
set -u
source local_setup.sh
PUPPET_SPEC_DRIVER=${DRIVER:-}
TOUCHED_FILE=/tmp/test_exec$$
# precondition: file to be touced should not exist.
if [ -e $TOUCHED_FILE ]; then
  rm $TOUCHED_FILE
fi
# puppet test
case "$PUPPET_SPEC_DRIVER" in
  apply)
    $BIN/puppet apply <<PP | tee $OUTFILE 
exec {'test': command=>"/bin/touch $TOUCHED_FILE"}
PP
  ;;
  agent)
  ;;
  *)
    $BIN/puppet resource -d exec test command="/bin/touch $TOUCHED_FILE" | tee $OUTFILE 	
  ;;
esac
# check output
grep 'executed successfully' $OUTFILE
# validate
[ -f $TOUCHED_FILE ]
