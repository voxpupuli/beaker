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

# JJM Putting both classes in the same manifest should work.
execute_manifest<<'MANIFEST3' && exit $EXIT_OK || exit $EXIT_FAILURE
class rainbow($color) {
  notify { "color": message => "Color is [${color}]" }
}
class { "rainbow": color => "green" }

class planet($moons) {
  notify { "planet": message => "Moons are [${moons}]" }
}
class { "planet": moons => "1" }

class rainbow::location($prism=false, $water=true) {
  notify { "${name}":
    message => "prism:[${prism}] water:[${water}]";
  }
}
class { "rainbow::location": prism => true, water => false; }

class rainbow::type($pretty=true, $ugly=false) {
  notify { "${name}":
    message => "pretty:[${pretty}] ugly:[${ugly}]";
  }
}
class { "rainbow::type": pretty => false, ugly => true; }
MANIFEST3

