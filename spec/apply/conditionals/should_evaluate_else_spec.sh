set -e

. local_setup.sh

$BIN/puppet apply <<PP | grep notice | grep else
if( 1 == 2) {
  notice('if')
} elsif(2 == 3) {
  notice('elsif')
} else {
  notice('else')
}
PP
