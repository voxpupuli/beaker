#!/bin/bash

set -e
set -u

. local_setup.sh

SYSTEM_COUNT=$( wc -l /etc/group | awk '{print $1}' )
RALSH_COUNT=$( puppet resource group | grep 'present' | wc -l )
if [ "$SYSTEM_COUNT" == "$RALSH_COUNT" ]; then
  exit 0
fi
echo "system count $SYSTEM_COUNT"
echo "ralsh count $RALSH_COUNT"
exit 1
