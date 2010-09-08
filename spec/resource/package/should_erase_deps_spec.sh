#!/bin/bash

set -e
set -u

source spec/setup.sh

if ! which rpm ; then NOT_APPLICABLE ; fi

PACKAGE='spectest'
DEPPACKAGE='spectestdep'

# precondition
# ensure that both packages are installed
if ! rpm -q $DEPPACKAGE; then
  yum -d 0 -e 0 -y install $DEPPACKAGE
fi

# run ralsh
$BIN/puppet resource package $PACKAGE ensure=purged | tee $OUTFILE

# postcondition
# both the package and the one that depends on it should be removed
grep 'ensure: removed' $OUTFILE
! rpm -q $PACKAGE
! rpm -q $DEPPACKAGE
