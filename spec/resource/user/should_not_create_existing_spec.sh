#!/bin/bash
# written by: Dan Bode
# tests that user resource will not add users that already exist.
#
set -e
set -u

. local_setup.sh
# precondtions
# 1. user bozo should exist
if ! getent passwd bozo ; then
  if grep ^bozo: /etc/group; then
    groupdel bozo
  fi
  useradd bozo
fi
# 2. usrs group should exist
if ! getent group bozo ; then
  groupadd bozo
fi

# run puppet, and ensure that it does not report user creation
# (it might be better to ensure that it doesnt report anything
! puppet resource user bozo ensure=present | grep 'created'
