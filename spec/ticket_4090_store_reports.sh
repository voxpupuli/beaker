#!/bin/bash

. `dirname $0`/setup.sh
driver_master_and_agent_locally_using_old_executables 
        
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

ls /tmp/puppet-$$-master/reports/puppetclient/*.yaml
head /tmp/puppet-$$-master/reports/puppetclient/*.yaml

# file exists and has a length greater than zero
[ -s /tmp/puppet-$$-master/reports/puppetclient/*.yaml ]
