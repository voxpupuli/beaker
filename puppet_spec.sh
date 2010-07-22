#!/bin/bash
#
# 2010-07-21 Jeff McCune <jeff@puppetlabs.com>
# Cleaned up this script

EXIT_NOT_APPLICABLE=11

# Error on unbound variable access
set -u

# JJM Set the TEST_DIR if it's not already set or passed as ARG 1
: ${TEST_DIR:=${1:-'./spec'}}

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

for SPEC in $(find $TEST_DIR -name '*_spec.sh')  ; do
  if ! [ -x $SPEC ] ; then
    echo -n p
    ((PENDING++))
    continue
  fi
  if $SPEC >& /dev/null ; then
    echo -n .
  else
    TEST_ERROR=$?
    # JJM Detect if script exited with code $EXIT_NOT_APPLICABLE
    if [ $TEST_ERROR -eq $EXIT_NOT_APPLICABLE ] ; then
      echo -n '~'
      ((SKIPPED++))
    else
      echo $SPEC >> $FAIL_LOG
      ((FAILURES++))
      echo -n F
    fi
  fi
  ((TOTAL++))
done

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

# JJM Exit "false" if the number of failures are not zero.
[ $FAILURES -eq 0 ]
