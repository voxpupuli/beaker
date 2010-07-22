#!/bin/bash

. spec/setup.sh

if [ `facter operatingsystem` != "Redhat" ] && [ `facter operatingsystem` != "CentOS" ] ; then NOT_APPLICABLE ; fi


#
# this test is prone to failures because it uses process lookup to determine failures.
#
#
#RALSH_RUNNING_COUNT=$( puppet resource service | egrep -B1 "ensure\s*=>\s*'running" | grep 'service {' | wc -l )
puppet resource service | egrep -B1 "ensure\s*=>\s*'running" | grep 'service {' | gawk -F"\'" '{print $2}' | sort  > /tmp/ralsh-running-list-$$
# this totally doenst work, it returns subservice statuses
#SERVICE_STATUS_RUNNING_COUNT=$( service --status-all | grep running | grep -v not | wc -l )
# blatently stolen from /sbin/service
if [-e /tmp/service-running-list-$$ ]; then
 rm /tmp/service-running-list-$$
fi
SERVICEDIR='/etc/init.d'
for SERVICE in $( ls $SERVICEDIR | sort | egrep -v "(functions|halt|killall|single|linuxconf)" ) ; do
  if env -i LANG="$LANG" PATH="$PATH" TERM="$TERM" "${SERVICEDIR}/${SERVICE}" status; then
    echo $SERVICE >> /tmp/service-running-list-$$
  fi
done
if diff /tmp/ralsh-running-list-$$ /tmp/service-running-list-$$ ; then
  exit 0
else
  exit 1
fi
