#!/bin/bash

set -e
set -u

. local_setup.sh

if [ -f /tmp/hosts-$$ ]; then
  rm /tmp/hosts-$$
fi

puppet resource host test1 ensure=present ip=127.0.0.2 target="/tmp/host-$$"
egrep '^127.0.0.2[[:space:]]+test1' /tmp/host-$$
