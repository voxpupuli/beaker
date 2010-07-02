#!/bin/bash

set -e
set -u

. ../../../local_setup.sh

if grep bozo /etc/group; then
  groupdel bozo
fi

$BIN/puppet resource group bozo ensure=present
grep bozo /etc/group
