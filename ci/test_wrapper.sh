#!/bin/bash

usage()
{
cat << EOF
usage: $0 options

./test_wrapper.sh -p git uri to puppet branch -f facter version or git topic branch uri

Run full acceptance test suite  on 2.6.next with Factor 1.5.8
  ./test_wrapper.sh -p origin/2.6.next -f 1.5.8

Run a specific acceptance test 2.6.next with Factor 1.5.8
  ./test_wrapper.sh -p origin/2.6.next -f 1.5.8 -t tests/acceptance/some_specific_test_to_run.rb

Run acceptance tests on special topic branch with Facter 1.5.8:
  ./test_wrapper.sh -p https://github.com/SomeDude/puppet/tree/ticket/2.6.next/6856-dangling-symlinks -f 1.5.8 

Skip installing new code; just run a test(s) on code already installed:
  ./test_wrapper.sh -p skip -f skip -t tests/acceptance/some_specific_test_to_run.rb


OPTIONS:
   -h      Show this message
   -p      puppet branch or URI
   -f      Facter version or URI
   -t      Test (or dir of tests) to execute
EOF
}

puppet=
facter=
tests='tests/acceptance'

while getopts "hp:f:t:" OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         p)
             puppet=$OPTARG
             ;;
         f)
             facter=$OPTARG
             ;;
         t)
             tests=$OPTARG
             ;;
         ?)
             usage
             exit
             ;;
     esac
done

if [[ -z $puppet ]] || [[ -z $facter ]] ; then
     usage
     exit 1
fi

cd puppet-acceptance

if [[ $puppet == "skip" ]] ; then 
  ./systest.rb -c ci/devtest.cfg --type git -p $puppet -t $tests --debug
else
  ./systest.rb --vmrun tiki -c ci/devtest.cfg --type git -p $puppet -f $facter -t $tests --debug
fi
