#!/bin/bash
source spec/setup.sh

backup_file /etc/hosts

echo '127.0.0.1 localhost localhost.localdomain' > /etc/hosts
ENSURE_COUNT=`puppet resource host localhost | grep present | wc -l`
[ $ENSURE_COUNT -eq '1' ]
status=$?

restore_file /etc/hosts

exit $status
