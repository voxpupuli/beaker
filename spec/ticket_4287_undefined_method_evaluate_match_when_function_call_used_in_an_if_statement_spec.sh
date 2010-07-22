#!/bin/bash
#
# 2010-07-19 Jeff McCune <jeff@puppetlabs.com>
#
# http://projects.puppetlabs.com/issues/4287

set -e
set -u
source spec/setup.sh
if execute_manifest <<'EOF'
$foo='abc'
if $foo != regsubst($foo,'abc','def') {
  notify { 'No issue here...': }
}
EOF
then
  exit $EXIT_OK
else
  exit $EXIT_FAILURE
fi
