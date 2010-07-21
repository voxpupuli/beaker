#!/bin/bash

set -e
set -u

source local_setup.sh

if ! getent group bozo; then
  groupadd bozo
fi

puppet resource group bozo | grep present
