#!/bin/bash

set -e
set -u

source spec/setup.sh

# JJM We expect 2.6.0rc3 to return an error
# and 2.6.0 final to not return an error line.
# Look for the line in the output and fail the test
# if we find it.
execute_manifest false <<'PP' | grep ^err:
exec { '/bin/echo -e "\nHello World\n"': }
PP
# rval is the exit status of grep
rval=$?

# JJM Exit with a proper failure code if the line was found
test $rval -eq 0 && exit $EXIT_FAILURE || exit $EXIT_OK

