#!/bin/bash
#
# 2010-08-02 Nan Liu
#
# http://projects.puppetlabs.com/issues/4285

set -e
set -u
source lib/setup.sh


# NL: Expect 2.6.0rc4 to return an error:
# Puppet::Parser::AST::Resource failed with error ArgumentError:
# Cannot alias File[file2] to [nil]; resource ["File", [nil]] already exists...
# Bug fixd by 2.6.0
if execute_manifest <<'EOF'
file { "file1":
    name => '/tmp/file1',
    source => "/tmp/",
}

file { "file2":
    name => '/tmp/file2',
    source => "/tmp/",
}
EOF
then
  exit $EXIT_OK
else
  exit $EXIT_FAILURE
fi
