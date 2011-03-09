#!/bin/bash
PASS="Puppetmaster!"

expect -c "spawn /opt/libvirt/bin/virsh -c esx://root@soko/?no_verify=1 list"
expect "\"Enter root's password for soko: \""
send "\"$PASS\r\""
result = expect "\"virsh # \""

echo "$result"

exit 0

result=$(expect -c "
spawn /opt/libvirt/bin/virsh -c esx://root@soko/?no_verify=1 list
expect \"Enter root's password for soko: \"
send \"$PASS\r\"
expect \"virsh # \"
")
echo "$result"

#expect \"root@tb-driver:~# \"
