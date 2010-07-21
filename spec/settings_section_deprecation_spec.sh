#!/bin/bash
#
# 2010-07-21 Jeff McCune <jeff@puppetlabs.com>
# Cleaned up

set -e
set -u

source spec/setup.sh
source spec/util.sh

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
start_puppetmasterd 2>&1 >"${OUTPUT}"
start_puppetd
stop_puppetmasterd

grep deprecated "${OUTPUT}" && exit $EXIT_OK || exit $EXIT_FAILURE

