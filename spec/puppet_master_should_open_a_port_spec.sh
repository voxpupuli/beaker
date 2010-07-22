#!/bin/bash
#
set -u
source spec/setup.sh

PORT=18140

# JJM Note the use of a string literal.
# The variable will be dereferenced when the trap fires.
# "Idiom - If $master_pid length is nonzero, then kill $master_pid"
trap '{ test -n "${master_pid:-}" && kill "${master_pid}" ; }' EXIT

mkdir -p /tmp/puppet-$$-master/manifests
puppet master \
  --vardir /tmp/puppet-$$-master-var \
  --confdir /tmp/puppet-$$-master \
  --rundir /tmp/puppet-$$-master \
  --no-daemonize --autosign=true \
  --verbose --debug --color false \
  --certname=localhost --masterport ${PORT:-18140} &
master_pid=$!

# Wait for the master port to be availalbe
wait_until_master_is_listening $master_pid

# Only look for 4 seconds since we've already waited.
for I in `seq 0 4` ; do
  if lsof -i -n -P | grep '\*:'$PORT | grep $master_pid ; then
    status=${EXIT_OK}
    break
  else
    status=${EXIT_FAILURE}
    sleep 1
  fi
done

killwait ${master_pid}

# JJM Remove the exit trap since we're about to exit cleanly.
trap '' EXIT
exit $status

