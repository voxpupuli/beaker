#!/bin/bash

source spec/setup.sh

start_puppet_master

puppet agent --vardir /tmp/puppet-$$ --confdir /tmp/puppet-$$ --rundir /tmp/puppet-$$ --no-daemonize --onetime --server localhost --debug --masterport $MASTER_PORT

stop_puppet_master

exit 0
