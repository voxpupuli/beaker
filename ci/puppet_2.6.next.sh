#!/bin/bash

prep_vm() {
  cd ${workdir}/vmutil
  echo "Stop and clean the VMs"
  ./stop_and_clean.sh ci_64
  sleep 3
  echo "Revert to base snap shot and start the VMs"
  ./revert_and_start.sh ci_64
  sleep 10
}

run_test()  {
  cd $workdir
  echo "Test Pass Start"
  stime=`date`
  ./systest.rb -c ci/ci-64.cfg --type $test_type -p $puppet_ver -f $facter_ver -t tests/acceptance --debug
  echo "Test Pass Complete"
}
time}
mail_result() {
mailx -s "${stime}  Puppet Acceptance on Puppet ${puppet_ver}, Facter ${facter_ver}"  "dominic@puppetlabs.com, matt@puppetlabs.com, paul@puppetlabs.com, daniel@puppetlabs.com, jesse@puppetlabs.com, nigel@puppetlabs.com, markus@puppetlabs.com, jason@puppetlabs.com, max@puppetlabs.com, james@puppetlabs.com, luke@puppetlabs.com, zach@puppetlabs.com" < log/latest/summary.txt 
#mailx -s "${stime}  Puppet Acceptance on Puppet ${puppet_ver}, Facter ${facter_ver}"  "dominic@puppetlabs.com" < log/latest/summary.txt 
}


#############
# MAIN
#############

workdir=`pwd`


# puppet 2.6.next 
# factor 1.5.8
config='ci-64.cfg'
test_type='git'
puppet_ver='2.6.next'
facter_ver='1.5.8'
#prep_vm
run_test
#mail_result

# puppet 2.6.next 
# factor master (1.5.9)
config='ci-64.cfg'
test_type='git'
puppet_ver='2.6.next'
facter_ver='master'
#prep_vm
run_test
#mail_result
