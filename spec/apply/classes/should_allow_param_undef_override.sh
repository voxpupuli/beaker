#!/bin/bash
set -u
set -e
# we are testing that resources declared in a class
# can be applied with an include statement
source local_setup.sh
OUTFILE=/tmp/class_undef_override_out-$$
echo 'hello world!' > /tmp/class_undef_override_test-$$
puppet apply <<PP | tee $OUTFILE
class parent {
  file { 'test':
    path => '/tmp/class_undef_file-$$',
    source => '/tmp/class_undef_override_test-$$',
  }
}
class child inherits parent {
  File['test'] {
    source => undef,
    content => 'hello new world!',
  }
}
include parent
include child
PP
grep "hello new world" /tmp/class_undef_file-$$
