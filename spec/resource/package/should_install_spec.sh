#!/bin/bash
#
# author: Dan Bode
#  ensures that yum provider can uninstall a package
#
set -e
set -u

source lib/setup.sh

if ! which rpm ; then NOT_APPLICABLE ; fi

PACKAGE='spectest'

# precondition
# package should not be installed
if rpm -q $PACKAGE; then
  rpm -ef $PACKAGE
fi

# run ralsh
$BIN/puppet resource package $PACKAGE ensure=installed | tee $OUTFILE
 
# postcondition
# package should be installed
grep 'ensure: created' $OUTFILE
rpm -q $PACKAGE
