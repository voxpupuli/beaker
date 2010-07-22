#!/bin/bash

set -u
source spec/setup.sh
set -e

execute_manifest <<PP
file{'/tmp/hello.$$.txt': content => 'hello world'}
PP

if grep -q 'hello world' /tmp/hello.$$.txt; then
  exit $EXIT_OK
else
  exit $EXIT_FAILURE
fi

