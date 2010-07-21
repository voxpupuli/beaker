#!/bin/bash
#
# 2010-07-21 Jeff McCune <jeff@puppetlabs.com>
# Cleaned up

source spec/setup.sh
driver_master_and_agent_locally_using_old_executables

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

execute_manifest <<'PP' 2>&1 | tee /tmp/puppet-$$.output
notify{'this is a notify':}
PP

grep deprecated /tmp/puppet-$$.output
