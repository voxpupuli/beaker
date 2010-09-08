#!/bin/bash
# Jeff McCune <jeff@puppetlabs.com>
# 2010-07-31
#
# AffectedVersion: 2.6.0, 2.6.1rc1
# FixedVersion:
#
# Make sure two parameterized classes are able to be declared.
#

# Error out on any unexpected execution failures
set -e
# Error out on any unbound variable references
set -u

source lib/setup.sh
driver_standalone_using_files

class1='class rainbow($color) {
  notify { "color": message => "Color is [${color}]" }
}
class { "rainbow": color => "green" }'

class2='class planet($moons) {
  notify { "planet": message => "Moons are [${moons}]" }
}
class { "planet": moons => "1" }'

# Declaring one parameterized class works just fine
execute_manifest<<MANIFEST1
${class1}
MANIFEST1

# Make sure we try both classes stand-alone
execute_manifest<<MANIFEST2
${class2}
MANIFEST2

# JJM Putting both classes in the same manifest should work.
execute_manifest<<MANIFEST3 && exit $EXIT_OK || exit $EXIT_FAILURE
${class1}
${class2}
MANIFEST3

