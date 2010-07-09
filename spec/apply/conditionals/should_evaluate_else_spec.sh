set -e
#
# test that else clause will be reached
# if no expressions match
#
. local_setup.sh

$BIN/puppet apply <<PP | tee $OUTFILE 
if( 1 == 2) {
  notice('if')
} elsif(2 == 3) {
  notice('elsif')
} else {
  notice('else')
}
PP
grep 'else' $OUTFILE
