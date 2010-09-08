#!/bin/bash

set -e
set -u

source lib/setup.sh

if ! getent group bozo; then
  groupadd bozo
fi

! puppet resource group bozo ensure=present | grep '/Group[bozo]/ensure: created'
