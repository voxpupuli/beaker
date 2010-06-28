#!/bin/bash

. `dirname $0`/util.sh

. local_setup.sh

start_puppet_master

mkdir -p /tmp/puppet-$$/manifests

echo "file{'/tmp/hello.$$.txt': content => 'hello world'}" > /tmp/puppet-$$/manifests/site.pp

start_puppet_agent

kill $MASTER_PID

grep 'hello world' /tmp/hello.$$.txt
