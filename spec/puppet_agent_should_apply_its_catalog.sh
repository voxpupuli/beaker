#!/bin/bash

source spec/drivers.sh
driver_master_and_agent_locally
. local_setup.sh

execute_manifest <<PP
file{'/tmp/hello.$$.txt': content => 'hello world'}
PP

grep 'hello world' /tmp/hello.$$.txt
