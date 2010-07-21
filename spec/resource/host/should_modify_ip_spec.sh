#!/bin/bash

set -e
set -u

. local_setup.sh

FILE="/tmp/hosts-$$"

echo '127.0.0.2 test1 alias1' > $FILE

puppet resource host test1 ensure=present ip=127.0.0.3 host_aliases=alias1 target="$FILE"
egrep '^127.0.0.3[[:space:]]+test1[[:space:]]+alias1' $FILE
