#!/bin/bash

set -e
set -u

. local_setup.sh
RALSH_FILE=/tmp/ralsh-disabled-list-$$
SERVICE_FILE=/tmp/service-disabled-list-$$
# collect all service namevars 
puppet resource service | egrep -B2 "enable\s*=>\s*'false" | grep "service {" | awk -F"'" '{print $2}' | sort  > $RALSH_FILE

if [ -e $SERVICE_FILE ]; then
 rm $SERVICE_FILE
fi
SERVICEDIR='/etc/init.d'
for SERVICE in $( ls $SERVICEDIR | sort | egrep -v "(functions|halt|killall|single|linuxconf)" ) ; do
  if ! chkconfig $SERVICE; then
    echo $SERVICE >> $SERVICE_FILE
  fi
done
if diff $RALSH_FILE $SERVICE_FILE ; then
  exit 0
else
  exit 1
fi
