#!/bin/bash
#
# 2010-07-19 Jeff McCune <jeff@puppetlabs.com>
#
# http://projects.puppetlabs.com/issues/4287

set -e
set -u

source spec/setup.sh
execute_manifest <<EOF
\$foo = 'abc'
if \$foo != regsubst(\$foo,'abc','def') {
  notify { 'foo': }
}
EOF
