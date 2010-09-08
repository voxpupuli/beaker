#!/bin/bash
#
#  test that false evaluates to false
#
source lib/setup.sh

OUTFILE="/tmp/spec-$$.log"

puppet <<PP | tee $OUTFILE
if false {
} else {
  notice('false')
}
PP
grep 'false' $OUTFILE
