#!/bin/bash
#
#  test that false evaluates to false
#
source local_setup.sh

OUTFILE="/tmp/spec-$$.log"

$BIN/puppet <<PP | tee $OUTFILE
if false {
} else {
  notice('false')
}
PP
grep 'false' $OUTFILE
