#!/bin/bash
# written by: Dan Bode
# verifies that puppet resource creates a user and assigns the correct group
#
set -e
set -u

source local_setup.sh

# preconditions
# 1. user should not exist
if getent passwd bozo; then
  userdel bozo
fi
# 2. group should exist
if ! getent group bozo_test_group; then
  groupadd bozo_test_group
fi

# create user with group
"${BIN}"/puppet resource user bozo ensure=present gid=bozo_test_group

# check that user exists and has specified group
gid=$( getent group bozo_test_group | awk -F':' '{print $3}' )
getent passwd bozo | grep $gid
