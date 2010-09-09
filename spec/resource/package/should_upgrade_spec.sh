#!/bin/bash
# Author: Dan Bode
# ensures that a yum provider can upgrade to a specified version
#  

set -e
set -u

source lib/setup.sh
if ! which rpm ; then NOT_APPLICABLE ; fi

PACKAGE='spectest'
# we have to include the build number of puppet fails, YUCK!
OLD_VERSION='1.0-1'
VERSION='1.1-1'

# precondition
# ensure that old versipons of package is installed
if rpm -q $PACKAGE; then
  rpm -ef $PACKAGE
fi
yum install -d 0 -e 0 -y $PACKAGE-$OLD_VERSION

# run ralsh
$BIN/puppet resource package $PACKAGE ensure=$VERSION | tee $OUTFILE

# postcondition
# package should have been upgraded to desired version.
grep "ensure changed '${OLD_VERSION}' to '${VERSION}'" $OUTFILE
[ `rpm -q $PACKAGE` == "${PACKAGE}-${VERSION}" ] 
