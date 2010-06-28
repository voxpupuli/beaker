#!/bin/bash

if ! [ -f local_setup.sh ] ; then
        echo '
You must create a local_setup.sh so we know where to find the puppet libs.

Example:
'
        cat local_setup.example.sh
        exit 2
fi

let FAILURES=0
let TOTAL=0

FAIL_LOG=/tmp/$$.failures.txt
touch $FAIL_LOG

for SPEC in `find ./spec -name '*_spec.sh' -perm +111 ` ; do
        if $SPEC >& /dev/null ; then
                echo -n . 
        else
                echo $SPEC > $FAIL_LOG
                let "FAILURES+=1"
                echo -n F
        fi
        let "TOTAL+=1"
done
echo
echo "$TOTAL tests, $FAILURES failures"
cat -n $FAIL_LOG

[ $FAILURES -eq 0 ]
