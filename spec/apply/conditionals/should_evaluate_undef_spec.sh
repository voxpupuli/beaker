#!/bin/bash
source local_setup.sh

OUTFILE="/tmp/spec-$$.log"

puppet apply <<PP | tee $OUTFILE
if '' {
} else {
  notice('empty')
}
PP
grep empty $OUTFILE
