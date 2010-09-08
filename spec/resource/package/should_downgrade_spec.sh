#!/bin/bash

set -e
set -u

source spec/setup.sh
if ! which rpm ; then NOT_APPLICABLE ; fi

PACKAGE='spectest'
# we have to include the build number of puppet fails, YUCK!
OLD_VERSION='1.1-1'
VERSION='1.0-1'

# precondition
if rpm -q $PACKAGE; then
  rpm -ef $PACKAGE
fi
yum install -d 0 -e 0 -y $PACKAGE-$OLD_VERSION

# run ralsh
$BIN/puppet resource package $PACKAGE ensure=$VERSION | tee $OUTFILE

grep "ensure changed '${OLD_VERSION}' to '${VERSION}'" $OUTFILE
# postcondition
[ `rpm -q $PACKAGE` == "${PACKAGE}-${VERSION}" ] 
