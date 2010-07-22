#!/bin/bash

set -e
set -u

source spec/setup.sh

execute_manifest <<'PP'
exec { '/bin/echo -e "\nHello World\n"': }
PP
rval=$?

# JJM Exit with a proper failure code if puppet didn't run
test $rval -eq 0 && exit $EXIT_OK || exit $EXIT_FAILURE

