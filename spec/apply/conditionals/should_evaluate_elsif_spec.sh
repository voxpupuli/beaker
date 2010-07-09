#!/bin/bash

source local_setup.sh

$BIN/puppet apply <<PP | tee $OUTFILE
if( 1 == 3) {
  notice('if')
} elsif(2 == 2) {
  notice('elsif')
} else {
  notice('else')
}
PP
grep 'elsif' $OUTFILE
