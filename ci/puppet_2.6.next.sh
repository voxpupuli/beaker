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
  ./systest.rb -c ci/ci-64.cfg --type $test_type -p $puppet_ver -f $factor_ver -t tests/acceptance --debug
  echo "Test Pass Complete"

  rm -f ci/log/latest
  cp -R log/* ci/log
}

mail_result() {
mailx -s "Puppet Acceptance: 2.6.next, Factor 1.5.8"  "dominic@puppetlabs.com, matt@puppetlabs.com, paul@puppetlabs.com, daniel@puppetlabs.com, jesse@puppetlabs.com, nigel@puppetlabs.com, markus@puppetlabs.com, jason@puppetlabs.com, max@puppetlabs.com" < log/latest/summary.txt 
#  mailx -s "Puppet Acceptance: Puppet ${puppet_ver}, Factor ${factor_ver}"  "dominic@puppetlabs.com" < log/latest/summary.txt 
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
factor_ver='1.5.8'
prep_vm
run_test
mail_result

# puppet 2.6.next 
# factor master (1.5.9)
config='ci-64.cfg'
test_type='git'
puppet_ver='2.6.next'
factor_ver='master'
prep_vm
run_test
mail_result
