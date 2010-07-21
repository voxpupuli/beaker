#!/bin/bash

set -e
set -u

. local_setup.sh
#
# precondition - entry doesn't exist
#
if [ -f /tmp/host-$$ ]; then
  rm /tmp/host-$$
fi

puppet resource host test1 ensure=present target="/tmp/host-$$" host_aliases=alias1 | tee /tmp/spec-$$.log

# post-condition - ip address not specified, create should fail with message.
grep 'ip is a required attribute for hosts' /tmp/spec-$$.log
