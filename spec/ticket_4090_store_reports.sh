#!/bin/bash

. `dirname $0`/setup.sh
driver_master_and_agent_locally
        
puppet_conf <<CONF
[main]
  logdir=\$vardir/log
  ssldir=\$vardir/ssl
[puppetd]
  certname=puppetclient
  server=puppetmaster
  report=true
[puppetmasterd]
  certname=puppetmaster
  reports=store
CONF

execute_manifest <<PP
file{'/tmp/hello.$$.txt': content => 'hello world'}
PP

# file exists and has a length greater than zero
[ -s /tmp/puppet-$$/reports/puppetclient/*.yaml ]
