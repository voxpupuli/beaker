#!/bin/bash
#
# 2010-07-22 Jeff McCune <jeff@puppetlabs.com>
#
# AffectedVersion: 2.6.0rc4
# FixedVersion: 2.6.0
#
# Description: using a defined type in the class it's declared in
# causes an error.
#

set -u
source spec/setup.sh

OUTPUT="/tmp/puppet-$$.out"

execute_manifest <<'PP' >"${OUTPUT}"
class foo {
  define do_notify($msg) {
    notify { "Message for $name: $msg": }
  }
  do_notify { 'test_one': msg => 'a_message_for_you' }
}
include foo
PP

if egrep -q '^notice.*?Foo::Do_notify.*?a_message_for_you' "${OUTPUT}" ; then
  exit $EXIT_OK
else
  exit $EXIT_FAILURE
fi

