#!/bin/bash
#
# ensure that undefined variables evaluate as false
#
. local_setup.sh

OUTFILE="/tmp/spec-$$.log"

$BIN/puppet apply <<PP | tee $OUTFILE
if \$undef_var {
} else {
  notice('undef')
}
PP
grep 'undef' $OUTFILE
