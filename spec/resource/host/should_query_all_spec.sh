#!/bin/bash
source spec/setup.sh

backup_file /etc/hosts

echo '127.0.0.1 localhost localhost.localdomain' > /etc/hosts
echo '127.0.0.2 test1 localhost.localdomain' >> /etc/hosts
echo '127.0.0.3 test2 localhost.localdomain' >> /etc/hosts
echo '127.0.0.4 test3 localhost.localdomain' >> /etc/hosts

# this is a little hokey, I would rather check everything, not just the ensure lines
ENSURE_COUNT=`puppet resource host | grep present | wc -l`
[ $ENSURE_COUNT -eq '4' ]
status=$?

restore_file /etc/hosts

exit $status
