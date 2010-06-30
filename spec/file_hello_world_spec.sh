#!/bin/bash

. `dirname $0`/setup.sh

execute_manifest <<PP
file{'/tmp/hello.$$.txt': content => 'hello world'}
PP

grep 'hello world' /tmp/hello.$$.txt
