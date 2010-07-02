#!/bin/bash

set -e
set -u

. ../../../local_setup.sh

if ! grep bozo /etc/group; then
  groupadd bozo
fi

$BIN/puppet resource group bozo ensure=present gid=12768
egrep "bozo:\S*:12768" /etc/group
