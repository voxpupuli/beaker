#!/bin/bash

set -e
set -u

. local_setup.sh

if ! grep test1 /etc/hosts; then
  echo "127.0.0.2 test1" > /etc/hosts
fi

if [ -f /tmp/hosts-$$ ]; then
  rm /tmp/hosts-$$
fi
echo 'yoyo'
$BIN/puppet resource host test1 ensure=present target="/tmp/host-$$" host_aliases=alias1 
#| grep 'ip is a required attribute for hosts'
