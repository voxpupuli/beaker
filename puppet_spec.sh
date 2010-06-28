#!/bin/bash
let FAILURES=0
let TOTAL=0

for SPEC in `find ./spec -name '*_spec.sh'` ; do
	bash $SPEC || let "FAILURES+=1"
        let "TOTAL+=1"
done  
echo "$TOTAL tests, $FAILURES failures"
