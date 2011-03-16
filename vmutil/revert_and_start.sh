#!/bin/bash

usage()
{
  echo "revert_and_start.sh VM_image_file Snapshot_name"
  exit 1
}

if [ -z $1 ]; then
  echo "VM image file list missing!"
  usage
fi

if [ -z $2 ]; then
  echo "Snapshot name missing!"
  usage
fi

# Revert
./vmmanage.sh -i $1 -v $2
sleep 3

# Start
./vmmanage.sh -i $1 -g 
