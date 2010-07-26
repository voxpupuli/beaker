#!/bin/bash

set -e
set -u

source lib/setup.sh

if ! getent group bozo; then
  groupadd bozo
fi

puppet resource group bozo ensure=present gid=12768
getent group bozo | grep 12768
