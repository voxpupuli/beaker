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
if ! grep bozo /etc/passwd; then
  if grep bozo /etc/groups; then
    groupdel bozo
  fi
  useradd bozo
fi

# puppet resource ensures user is absent
$BIN/puppet resource user bozo ensure=absent
! getent passwd bozo
