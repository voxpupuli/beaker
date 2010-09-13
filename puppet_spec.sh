#!/bin/bash
#
# 2010-07-21 Jeff McCune <jeff@puppetlabs.com>
# Cleaned up this script

EXIT_OK=0
EXIT_FAILURE=10
EXIT_NOT_APPLICABLE=11

# Error on unbound variable access
set -u

# JJM Set the TEST_DIR if it's not already set or passed as ARG 1
: ${TEST_DIR:=${1:-'./spec'}}

print_results() {
  echo
  echo -n "$TOTAL tests, $FAILURES failures"
  if [ "$PENDING" -ne 0 ] ; then
    echo -n ", $PENDING pending"
  fi
  if [ "$SKIPPED" -ne 0 ] ; then
    echo -n ", $SKIPPED skipped"
  fi
  echo
  cat -n $FAIL_LOG
}

trap "print_results; exit" SIGINT

if ! [ -f local_setup.sh ] ; then
  echo 'You must create a local_setup.sh so we know where to find puppet.

Example:
'
  cat local_setup.example.sh
  exit 2
fi

FAILURES=0
TOTAL=0
PENDING=0
SKIPPED=0

FAIL_LOG=/tmp/$$.failures.txt
touch $FAIL_LOG

for SPEC in $(find $TEST_DIR -name '*_spec.sh' | sort)  ; do
  if ! [ -x $SPEC ] ; then
    echo -n p
    ((PENDING++))
    continue
  fi

  result=$($spec 2>&1)
  TEST_ERROR=$?

  if [ $TEST_ERROR -eq $EXIT_OK ] then
    echo -n .
  else
    # JJM Detect if script exited with code $EXIT_NOT_APPLICABLE
    if [ $TEST_ERROR -eq $EXIT_NOT_APPLICABLE ] ; then
      echo -n '~'
      ((SKIPPED++))
    else
      echo $SPEC   >> $FAIL_LOG
      echo $result >> $FAIL_LOG
      ((FAILURES++))
      echo -n F
    fi
  fi
  ((TOTAL++))
done

print_results

# JJM Exit with FAILURE status if the number of failures are not zero.
[ $FAILURES -eq 0 ] && exit $EXIT_OK || exit $EXIT_FAILURE
