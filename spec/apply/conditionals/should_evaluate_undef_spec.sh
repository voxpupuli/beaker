#!/bin/bash
source local_setup.sh
$BIN/puppet apply <<PP | tee $OUTFILE
if '' {
} else {
  notice('empty')
}
PP
grep empty $OUTFILE
