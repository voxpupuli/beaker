#!/bin/bash

if [ -z $1 ]; then
  echo "VM image file list missing!"
  exit 1
fi

# Revert
./vmmanage.sh -i $1 -v snap1
sleep 3

# Start
./vmmanage.sh -i $1 -g 
