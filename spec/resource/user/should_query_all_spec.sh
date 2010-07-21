#!/bin/bash
# written by: Dan Bode
# ensure that puppet queries the correct number of users
# (it might make sense to make sure its reporting the correct users later)
set -e
set -u

. local_setup.sh

# count the lines in /etc/passwd
SYSTEM_COUNT=$( wc -l /etc/passwd | awk '{print $1}')
# could the users that puppet knows exist
RALSH_COUNT=$( puppet resource user | grep 'present' | wc -l )
# the counts should be the same
if [ "$SYSTEM_COUNT" == "$RALSH_COUNT" ]; then
  exit 0
fi
echo "system count $SYSTEM_COUNT"
echo "ralsh count $RALSH_COUNT"
exit 1
