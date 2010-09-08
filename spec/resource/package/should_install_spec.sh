#!/bin/bash

set -e
set -u

source lib/setup.sh

if ! which rpm ; then NOT_APPLICABLE ; fi

PACKAGE='spectest'

# precondition
if rpm -q $PACKAGE; then
  rpm -ef $PACKAGE
fi

# run ralsh
$BIN/puppet resource package $PACKAGE ensure=installed | tee $OUTFILE
 
# postcondition
grep 'ensure: created' $OUTFILE
rpm -q $PACKAGE
