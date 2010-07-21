set -e

. local_setup.sh

puppet apply <<PP | grep notice | grep if
if( 1 == 1) {
  notice('if')
} elsif(2 == 2) {
  notice('elsif')
} else {
  notice('else')
}
PP
