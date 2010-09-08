#!/bin/bash
#
# written by: Dan Bode
# 
# test that we can query and find a user that exists.
#
set -e
set -u

source lib/setup.sh
# precondition
# 1. user should exist
if ! getent passwd bozo; then
  useradd bozo
fi
# query for user, ensure that it is reported as present
puppet resource user bozo | grep present
