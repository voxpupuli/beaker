#!/bin/bash
#
#  test that false evaluates to false
#
source local_setup.sh

$BIN/puppet <<PP | tee $OUTFILE
if false {
} else {
  notice('false')
}
PP
grep 'false' $OUTFILE
