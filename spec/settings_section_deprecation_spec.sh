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

execute_manifest <<'PP' 2>&1 | tee ${OUTPUT}
notify{'this is a notify':}
PP

grep deprecated "${OUTPUT}" && exit $EXIT_OK || exit $EXIT_FAILURE

