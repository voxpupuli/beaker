#!/bin/bash
# 
# description:
# author:
set -e
set -u
source local_setup.sh
PUPPET_SPEC_DRIVER=
# precondition:
#
#
if [  ]; then
    
fi
# puppet test
case "$PUPPET_SPEC_DRIVER" in
  apply)
    $BIN/puppet apply <<PP | tee $OUTFILE 
PP
  ;;
  agent)
  ;;
  *)
    $BIN/puppet resource  | tee $OUTFILE 	
  ;;
esac
# check output
# validate
