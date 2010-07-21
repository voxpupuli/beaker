#!/bin/bash

set -e
set -u

. local_setup.sh

PATTERN='^127.0.0.2[[:space:]]+test1'
FILE="/tmp/hosts-$$"

echo '127.0.0.2 test1' > $FILE

puppet resource host test1 ensure=absent ip=127.0.0.2 target="$FILE"
! egrep $PATTERN $FILE
