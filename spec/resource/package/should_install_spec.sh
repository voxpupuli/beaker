#!/bin/bash

set -e
set -u

source spec/setup.sh

if ! which rpm ; then NOT_APPLICABLE ; fi

PACKAGE='yum-cron'

# precondition
if rpm -q $PACKAGE; then
  rpm -ef $PACKAGE
fi

# run ralsh
puppet resource package yum-cron ensure=installed | grep 'ensure: created'

# postcondition
rpm -q $PACKAGE
