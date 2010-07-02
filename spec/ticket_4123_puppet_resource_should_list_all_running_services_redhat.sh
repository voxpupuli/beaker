#!/bin/bash

. `dirname $0`/setup.sh
#
# this test is prone to failures because it uses process lookup to determine failures.
#
#
RALSH_SERVICE_RUNNING_COUNT=`$BIN/puppet resource service | egrep "ensure\s*=>\s*'running" | wc -l`
SERVICE_STATUS_RUNNING_COUNT=`service --status-all | grep running | grep -v not | wc -l`
if [ "$RALSH_SERVICE_RUNNING_COUNT" == "$SERVICE_STATUS_RUNNING_COUNT" ] ; then
  exit 0
else
  echo "ralsh count ${RALSH_SERVICE_RUNNING_COUNT} services"
  echo "service --status-all counts ${SERVICE_STATUS_RUNNING_COUNT} services"
  exit 1
fi
