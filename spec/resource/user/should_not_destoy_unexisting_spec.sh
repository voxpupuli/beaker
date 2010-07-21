#!/bin/bash
#
# written by: Dan Bode
# ensure that puppet does not report removing a user that does not exist
set -e
set -u

. local_setup.sh

# precondition
# 1. user should not exist
if getent passwd bozo; then
  userdel bozo
fi

# ensure that puppet does not report removing a user that did not exist
! puppet resource user bozo ensure=absent | grep 'removed'
