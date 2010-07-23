#!/bin/bash
#
# 2010-07-22 Jeff McCune <jeff@puppetlabs.com>
#
# AffectedVersion: 2.6.0rc3
# FixedVersion: 2.6.0

set -u

source spec/setup.sh

# JJM We expect 2.6.0rc3 to return an error
# and 2.6.0 final to not return an error line.
# Look for the line in the output and fail the test
# if we find it.
execute_manifest <<'PP' | grep '^err:'
exec { '/bin/echo -e "\nHello World\n"': }
PP
# rval is the exit status of grep
rval=$?

# JJM Exit with a proper failure code if the line was found
if [ $rval -eq 0 ]
  exit $EXIT_FAILURE
else
  exit $EXIT_OK
fi

