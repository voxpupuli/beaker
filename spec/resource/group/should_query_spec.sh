#!/bin/bash

set -e
set -u

. local_setup.sh

if ! getent group bozo; then
  groupadd bozo
fi

$BIN/puppet resource group bozo | grep present
