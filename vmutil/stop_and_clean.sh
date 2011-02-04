#!/bin/bash

if [ -z $1 ]; then
  echo "VM image file list missing!"
  exit 1
fi

# Stop
./vmmanage.sh -i $1 -s 
sleep 3

# Clean
./vmmanage.sh -i $1 -c 
