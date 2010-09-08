#!/bin/bash

set -e
set -u

source lib/setup.sh

if getent group bozo; then
  groupdel bozo
fi

puppet resource group bozo ensure=present
getent group bozo
