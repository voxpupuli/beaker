#!/bin/bash
# 
# description:
# author:
set -e
set -u
source local_setup.sh
PUPPET_SPEC_DRIVER=${DRIVER:-}
TOUCHFILE='/tmp/touched-$$'
DONTTOUCHFILE='/tmp/donttouch-$$'
# precondition:
#
#
if [ ! -f $TOUCHFILE ]; then
  touch $TOUCHFILE
fi
if [ ! -f $DONTTOUCHFILE ]; then
  rm -f $DONTTOUCHFILE 
fi
# puppet test
case "$PUPPET_SPEC_DRIVER" in
  apply)
    $BIN/puppet apply <<PP | tee $OUTFILE 
exec { "test$$": comand => '/bin/touch $DONTTOUCHFILE', creates => "$TOUCHFILE"}
PP
  ;;
  agent)
  ;;
  *)
    $BIN/puppet resource exec test$$ command="/bin/touch $DONTTOUCHFILE" creates="$TOUCHFILE" | tee $OUTFILE 	
  ;;
esac
# check output: nothing should be executed.
! grep 'executed successfully' $OUTFILE
# validate : file should not be touched.
[ ! -f $DONTTOUCHFILE ]
