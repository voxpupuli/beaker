#!/bin/bash

workdir=`pwd`

# Prep the VMs
cd ${workdir}/vmutil
echo "Stop and clean the VMs"
./stop_and_clean.sh ci_64
sleep 3
echo "Revert to base snap shot and start the VMs"
./revert_and_start.sh ci_64
sleep 10

cd $workdir
echo "Test Pass Start"
# ./systest.rb -c ci/ci-64.cfg --type git -p 2.6.next -f 1.5.8 -t tests/acceptance --debug
./systest.rb -c ci/ci-64.cfg --type git -p 2.6.next -f 1.5.8 -t tests/post_install/ValidatePuppet.rb
echo "Test Pass Complete"
