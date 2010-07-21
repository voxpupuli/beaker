#!/bin/bash
#
# verify that we can modify the gid
#
set -e
set -u

. local_setup.sh

# predonctions:
# 1. ensure that groups exists
#   tmp group
if ! getent group bozo_test_group; then
  groupadd bozo_test_group
fi
# group we will change to
if ! getent group bozo_new_group; then
  groupadd bozo_new_group
fi
# ensure that user exists and is set to a different group
if ! getent passwd bozo; then
  useradd bozo -g bozo_test_group
else
  usermod -g bozo_test_group bozo
fi

getent passwd bozo

# user puppet resource to modify users primary group
puppet resource user bozo ensure=present gid=bozo_new_group
# capture groups gid
gid=$( getent group bozo_new_group | awk -F':' '{print $3}' )
echo $gid
# verify that user was assigned the new group
getent passwd bozo | grep $gid
