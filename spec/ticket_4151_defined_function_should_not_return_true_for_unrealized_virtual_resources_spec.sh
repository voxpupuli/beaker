#!/bin/bash
#
# Jeff McCune <jeff@puppetlabs.com>
# 2010-07-06
#
# This script is expected to exit non-zero if ticket 4151 has not been
# fixed.
#
# The expected behavior is for defined() to only return true if a virtual
# resource has been realized.
#
# This test creates a virtual resource, does NOT realize it, then calls
# the defined() function against it.  If defined returns true, there will
# be an error since Notify["goodbye"] will require a resource which has
# not been realized.
#

set -e
set -u

source lib/setup.sh
driver_standalone_using_files

execute_manifest <<PP
@notify { "hello": }
if (defined(Notify["hello"])) { \$requires = [ Notify["hello"] ] }
notify { "goodbye": require => \$requires }
PP

