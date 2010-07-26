#!/bin/bash
source lib/setup.sh

OUTFILE="/tmp/spec-$$.log"

puppet apply <<PP | tee $OUTFILE
if '' {
} else {
  notice('empty')
}
PP
grep empty $OUTFILE
