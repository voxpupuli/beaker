#!/bin/bash

. `dirname $0`/util/start_puppet_master.sh

. local_setup.sh

start_puppet_master

mkdir -p /tmp/puppet-$$/manifests

echo "file{'/tmp/hello.$$.txt': content => 'hello world'}" > /tmp/puppet-$$/manifests/site.pp

$BIN/puppet agent --vardir /tmp/puppet-$$ --confdir /tmp/puppet-$$ --rundir /tmp/puppet-$$ --no-daemonize --onetime --server localhost --debug --masterport $MASTER_PORT

kill $MASTER_PID

grep 'hello world' /tmp/hello.$$.txt
