#!/bin/bash

. `dirname $0`/setup.sh
        
$BIN/puppet kick hostname1 | tee /tmp/puppet-kick-$$.txt

grep "Triggering hostname1" /tmp/puppet-kick-$$.txt
