#!/bin/bash

usage() 
{
cat << EOF
usage: $0 [ -f || -i ] FILE -v SNAPSHOT_NAME -p -g -s -l -r

OPTIONS:
   -h       Show this message
   -f FILE  path to VM image file
   -i FILE  path to file with list of VM images
   -v NAME  Revert VM image FILE to snapshot NAME (requires -f or -i)
   -p NAME  Take snapshot NAME of VM image FILE (requires -f or -i)
   -g       Start VM FILE (requires -f or -i)
   -s       Stop VM FILE (requires -f or -i)
   -l       List snap shots for VM image FILE (requires -f or -i)
   -c       Clean-up lock files (all VMs must be off)
   -r       List running VMs 
EOF
}

vmrun()
{
  IFS=$'\n'
  vmexec="/Library/Application\ Support/VMware\ Fusion/vmrun"
  for vm in $vmimages; do
    echo "Executing ${cmd} on ${vm}"
    #sleep $zzz
    /Library/Application\ Support/VMware\ Fusion/vmrun -T fusion $cmd $vm $opts
  done
}



#########################
# Main
#########################
 
cmd=""
opts=""
zzz=0       # secs to sleep between starting/stopping VMs -- ease stress when starting many VMs
while getopts  "hgsp:v:lrf:i:c" flag; do
  case $flag in
    h)
      usage
      exit
     ;; 
    g) # go - start VM
      cmd="start"
      opts="nogui"
      zzz=3
    ;;
    s) # stop VM
      cmd="stop"
      opts="soft"
      zzz=3
    ;;
    p) # take a snapshot of VM
      cmd=snapshot
      opts=$OPTARG
    ;;
    v) # revert back to snapshot
      cmd=revertToSnapshot    
      opts=$OPTARG
    ;;
    l) # list all snapshots for VMs
      cmd=listSnapshots
    ;;
    r)  # list all currently running VMs
      /Library/Application\ Support/VMware\ Fusion/vmrun -T fusion list
      exit
    ;;
    f)  # single vm image to manage
        vmimages="$OPTARG"
    ;;
    i)  # index of vm images to manage
        vmimages=`cat ${OPTARG}`
    ;;
    c)  # clean up hanging about lock files
      /Library/Application\ Support/VMware\ Fusion/vmrun -T fusion list |  grep -c 'VMs: 0'
      if [ $? != 0 ] ; then    # grep should rerturn non-zero as this regex should fail
        echo "VMs appear to be running.  Please stop VMs to clean lock files"
        exit 1
      else
        echo "Cleaning lock files"
        find . -type d -name *.lck | grep -v ajax | xargs rm -rf
      fi
      exit 0
    ;;
  esac
done

# If we reach here, a vmimage must have been specified via -f or -i
if [ -z "$vmimages" ]; then
  echo "No vmimage(s) defined - please specify -f or -i"
  usage
  exit
else
  vmrun   # execute the command for VM(s)
fi
