#!/bin/bash
# written by : Dan Bode
# 
# verify that puppet resource correctly destroys users.
# 
set -e
set -u

. local_setup.sh
# preconditions:
# 1. user bozo should exist
if ! getent passwd bozo; then
  if getent group bozo; then
    groupdel bozo
  fi
  useradd bozo
fi

# puppet resource ensures user is absent
puppet resource user bozo ensure=absent
! getent passwd bozo
