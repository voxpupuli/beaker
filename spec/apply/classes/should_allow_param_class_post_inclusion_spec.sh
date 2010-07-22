#!/bin/bash
#

set -u
set -e

# we are testing that resources declared in a class
# can be applied with an include statement
source local_setup.sh
OUTFILE=/tmp/class_param_use-$$
puppet apply <<PP | tee $OUTFILE
class x(\$y, \$z) {
  notice("\${y}-\${z}")
}
class {x: y => '1', z => '2'}
include x
PP
grep "1-2" $OUTFILE
