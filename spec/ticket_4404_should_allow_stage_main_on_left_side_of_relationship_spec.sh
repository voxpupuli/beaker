#!/bin/bash
# Jeff McCune <jeff@puppetlabs.com>
# 2010-07-29
#
# AffectedVersion: <= 2.6.0rc1
# FixedVersion:
#
# This specification makes sure the syntax:
# Stage[main] -> Stage[last]
# works as expected
#

# Error out on any unexpected execution failures
set -e
# Error out on any unbound variable references
set -u

source lib/setup.sh
driver_standalone_using_files

# JJM Make sure we exit $EXIT_FAILURE to denote a true test failure.
# Also note, this works even with set -e
execute_manifest <<'PP' && exit $EXIT_OK || exit $EXIT_FAILURE
stage { [ "pre", "post" ]: }
Stage["pre"] -> Stage["main"] -> Stage["post"]
class one   { notify { "class one, first stage":   } }
class two   { notify { "class two, second stage":  } }
class three { notify { "class three, third stage": } }
class { "one": stage => pre }
class { "two": }
class { "three": stage => post }
PP

