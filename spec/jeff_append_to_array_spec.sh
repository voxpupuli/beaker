#!/bin/bash
# Jeff McCune <jeff@puppetlabs.com>
# 2010-08-17
#
# AffectedVersion:
# FixedVersion:
#

# Error out on any unexpected execution failures
set -e
# Error out on any unbound variable references
set -u

source lib/setup.sh
driver_standalone_using_files

# JJM Putting both classes in the same manifest should work.
execute_manifest<<'MANIFEST' && exit $EXIT_OK || exit $EXIT_FAILURE
class parent { 
  $arr1 = [ "parent array element" ]
}
class parent::child inherits parent {
  $arr1 += [ "child array element" ]
  notify { $arr1: }
}
include parent::child
MANIFEST

