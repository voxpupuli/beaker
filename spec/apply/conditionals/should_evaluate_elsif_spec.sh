set -e

. local_setup.sh

$BIN/puppet apply <<PP | grep notice | grep elsif
if( 1 == 3) {
  notice('if')
} elsif(2 == 2) {
  notice('elsif')
} else {
  notice('else')
}
PP
