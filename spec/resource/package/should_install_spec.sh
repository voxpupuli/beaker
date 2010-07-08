#!/bin/bash

set -e
set -u

source local_setup.sh

PACKAGE='yum-cron'

# precondition
if rpm -q $PACKAGE; then
  rpm -ef $PACKAGE
fi

# run ralsh
$BIN/puppet resource package yum-cron ensure=installed | grep 'ensure: created'

# postcondition
rpm -q $PACKAGE
