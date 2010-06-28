#!/bin/bash

. `dirname $0`/util/start_puppet_master.sh

. local_setup.sh

start_puppet_master

$BIN/puppet agent --vardir /tmp/puppet-$$ --confdir /tmp/puppet-$$ --rundir /tmp/puppet-$$ --no-daemonize --onetime --server localhost --debug --masterport $MASTER_PORT

kill $MASTER_PID

exit 0
