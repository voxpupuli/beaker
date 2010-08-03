#!/bin/bash
#
# 2010-08-02 Nan Liu
#
# http://projects.puppetlabs.com/issues/4289

set -e
set -u
source lib/setup.sh

# NL: Facter should return OS version instead of kernel version for OEL
# test script only applicable to OEL, provided based on ticked info, not verified.
(facter operatingsystem | grep -i OEL) || exit $EXIT_NOT_APPLICABLE
(facter operatingsystemrelease | grep '^[0-9].[0-9]$') && exit $EXIT_OK || exit $EXIT_FAILURE
