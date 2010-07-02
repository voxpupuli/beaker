#!/bin/bash


. ../../../local_setup.sh

echo '127.0.0.1 localhost localhost.localdomain' > /etc/hosts
ENSURE_COUNT=`$BIN/puppet resource host localhost | grep present | wc -l`
[ $ENSURE_COUNT -eq '1' ]
