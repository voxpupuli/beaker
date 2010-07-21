#!/bin/bash

set -e
set -u

source local_setup.sh

if getent group bozo; then
  groupdel bozo
fi

! puppet resource group bozo ensure=absent | grep 'notice: /Group[bozo]/ensure: removed'
