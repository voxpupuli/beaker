#!/bin/bash

source spec/setup.sh

execute_manifest <<PP
file{'/tmp/hello.$$.txt': content => 'hello world'}
PP

grep 'hello world' /tmp/hello.$$.txt
