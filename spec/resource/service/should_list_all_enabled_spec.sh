#!/bin/bash

. local_setup.sh
# count ralshes enabled services
RALSH_SERVICE_ENABLED_COUNT=$( puppet resource service | egrep "enable\s*=>\s*'true" | wc -l )
# chkconfigs enabled service count
SERVICE_ENABLED_COUNT=0
for service in $( chkconfig --list | awk -F ' ' '{print $1}' ); do
  chkconfig $service
  if [ $? == 0 ]; then
    SERVICE_ENABLED_COUNT=$(( $SERVICE_ENABLED_COUNT + 1 ))
  fi
done
#SERVICE_ENABLED_COUNT=`chkconfig --list | grep ':on' | wc -l`
if [ "$RALSH_SERVICE_ENABLED_COUNT" == "$SERVICE_ENABLED_COUNT" ] ; then
  exit 0
else
  ralsh service | grep -B2 true | grep service | awk -F"'" '{print $2}' | sort > /tmp/sorted-ralsh-$$
  for service in $(chkconfig --list | awk '{print $1}'); do
    if chkconfig $service; then
      echo $service >> /tmp/sorted-service-$$
    fi
  done
  cat /tmp/sorted-service-$$ | sort > /tmp/sorted-service-$$
  echo "ralsh count ${RALSH_SERVICE_ENABLED_COUNT} services"
  echo "chkconfig --list counts ${SERVICE_ENABLED_COUNT} services"
  exit 1
fi
