#!/bin/bash

set -e
set -u

. local_setup.sh

FILE="/tmp/hosts-$$"

echo '127.0.0.2 test1 alias1' > $FILE

puppet resource host test1 ensure=present ip=127.0.0.2 host_aliases=alias2 target="$FILE"
egrep '^127.0.0.2[[:space:]]+test1[[:space:]]+alias2' $FILE
