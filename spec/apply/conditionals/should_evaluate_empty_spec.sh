#!/bin/bash
#
# ensure that undefined variables evaluate as false
#

set -e
set -u

source local_setup.sh

OUTFILE="/tmp/spec-$$.log"

puppet apply <<PP | tee $OUTFILE
if \$undef_var {
} else {
  notice('undef')
}
PP
grep 'undef' $OUTFILE
