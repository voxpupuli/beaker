#!/bin/bash

set -e
set -u

source spec/setup.sh

if ! which rpm ; then NOT_APPLICABLE ; fi

PACKAGE='spectest'

# precondition
if ! rpm -q $PACKAGE; then
  yum -d 0 -e 0 -y install $PACKAGE
fi

# run ralsh
$BIN/puppet resource package $PACKAGE ensure=absent | tee $OUTFILE
 

# postcondition
grep 'ensure: removed' $OUTFILE
! rpm -q $PACKAGE
