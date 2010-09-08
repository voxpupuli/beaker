#!/bin/bash
#
# author: Dan Bode
#
# ensure that yum provider can uninstall a package
#
set -e
set -u

source lib/setup.sh

if ! which rpm ; then NOT_APPLICABLE ; fi

PACKAGE='spectest'

# precondition
# package should be installed
if ! rpm -q $PACKAGE; then
  yum -d 0 -e 0 -y install $PACKAGE
fi

# run ralsh
$BIN/puppet resource package $PACKAGE ensure=absent | tee $OUTFILE
 

# postcondition
# package should be uninstalled
grep 'ensure: removed' $OUTFILE
! rpm -q $PACKAGE
