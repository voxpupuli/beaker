#!/bin/bash

set -e
set -u

. local_setup.sh

FILE="/tmp/hosts-$$"

echo '127.0.0.2 test1 alias1' > $FILE

! puppet resource host test1 ensure=present ip=127.0.0.2 host_aliases=alias1 target="$FILE" | grep 'notice: /Host[test1]/ensure: created' 
