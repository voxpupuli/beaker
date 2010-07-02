#!/bin/bash

set -e
set -u

. ../../../local_setup.sh
# find the total number of disabled service that ralsh reports
RALSH_SERVICE_DISABLED_COUNT=$($BIN/puppet resource service | egrep "enable\s*=>\s*'false" | wc -l)
# count the number of 
SERVICE_DISABLED_COUNT=0
for service in $(chkconfig --list | awk '{print $1}'); do
  if ! chkconfig $service; then
    (( SERVICE_DISABLED_COUNT++ ))
  fi
done
if [ "$RALSH_SERVICE_DISABLED_COUNT" == "$SERVICE_DISABLED_COUNT" ] ; then
  exit 0
else
  echo "ralsh count ${RALSH_SERVICE_DISABLED_COUNT} services"
  echo "chkconfig --list counts ${SERVICE_DISABLED_COUNT} services"
  exit 1
fi
