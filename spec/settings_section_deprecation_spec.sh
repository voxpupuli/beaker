#!/bin/bash
#
# 2010-07-21 Jeff McCune <jeff@puppetlabs.com>
# Cleaned up

set -u

source lib/setup.sh

driver_master_and_agent_locally_using_old_executables

OUTPUT=/tmp/puppet-$$.output
MANIFEST=/tmp/puppet-$$-master/manifests/site.pp

puppet_conf <<'CONF'
[main]
  logdir=$vardir/log
  ssldir=$vardir/ssl
[puppetd]
  certname=puppetclient
  report=true
[puppetmasterd]
  reports=store
CONF

# JJM Create the manifest file for puppet master
echo 'notify{"this is a notify":}' > "${MANIFEST}"

# Start puppetmasterd, redirect output to a file
# JJM Note, not using the start_puppetmasterd
mkdir -p /tmp/puppet-$$-master/manifests
puppetmasterd \
  --vardir /tmp/puppet-$$-master-var \
  --confdir /tmp/puppet-$$-master \
  --rundir /tmp/puppet-$$-master \
  --no-daemonize --autosign=true \
  --verbose --debug --color false \
  --certname=localhost --masterport 18140 2>&1 >"${OUTPUT}" &
master_pid=$!

# Wait for the master port to be availalbe
wait_until_master_is_listening $master_pid

start_puppetd

killwait ${master_pid}

if grep -q deprecated "${OUTPUT}"; then
  exit $EXIT_OK
else
  exit $EXIT_FAILURE
fi

