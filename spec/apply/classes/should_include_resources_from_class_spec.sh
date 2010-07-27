#!/bin/bash
set -u
set -e
# we are testing that resources declared in a class
# can be applied with an include statement
source lib/setup.sh

puppet apply <<PP | tee /tmp/class_include-$$
class x {
  notify{'a':}
}
include x
PP
grep "defined 'message' as 'a'" /tmp/class_include-$$
