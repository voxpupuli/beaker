#!/bin/bash
# 
# checks that puppet resource can add the user bozo.
# verifies that it create the same group by default
set -e
set -u

. local_setup.sh

if getent passwd bozo; then
  userdel bozo
fi

if getent group bozo; then
  groupdel bozo
fi

puppet resource user bozo ensure=present
getent passwd bozo && getent group bozo
