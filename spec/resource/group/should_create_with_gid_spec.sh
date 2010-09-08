#!/bin/bash
#
# test that we can set a groups gid
#

source lib/setup.sh

#
# precondition
#  - group should not exist
GROUP=bozo$$
if getent group $GROUP; then
  groupdel $GROUP
fi

$BIN/puppet resource group $GROUP ensure=present gid=12768
getent group $GROUP | grep 12768
