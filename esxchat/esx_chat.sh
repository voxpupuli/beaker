#!/bin/bash
PASS="Puppetmaster!"

result=$(expect -c "
spawn /opt/libvirt/bin/virsh -c esx://root@soko/?no_verify=1 list
expect \"Enter root's password for soko: \"
send \"$PASS\r\"
expect \"virsh # \"
")
echo "$result"
