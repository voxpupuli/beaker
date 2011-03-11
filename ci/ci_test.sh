#!/bin/bash

run_test()  {
  cd $workdir
  echo "Test Pass Start"
  stime=`date`
  ./systest.rb --vmrun -c ci/ci-64.cfg --type $test_type -p $puppet_ver -f $facter_ver -t tests/acceptance --debug
  echo "Test Pass Complete"
}

mail_result() {
mailx -s "${stime}  Puppet Acceptance on Puppet ${puppet_ver}, Facter ${facter_ver}"  "dominic@puppetlabs.com" < log/latest/summary.txt 
}


#############
# MAIN
#############

cd $HOME/devenv/puppet-acceptance
workdir=`pwd`

# puppet 2.6.next 
# factor 1.5.8
config='ci-64.cfg'
test_type='git'
puppet_ver='2.6.next'
facter_ver='1.5.8'
run_test
mail_result
