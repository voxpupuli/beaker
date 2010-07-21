#!/bin/bash

set -e
set -u

. local_setup.sh

if getent passwd bozo; then
  userdel bozo
fi

if ! getent group bozo; then
  groupadd bozo
fi

puppet resource group bozo ensure=absent
! getent group bozo
