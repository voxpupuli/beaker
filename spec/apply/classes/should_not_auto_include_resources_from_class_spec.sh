set -e
#
# test that resource declared in classes are not applied without include
#
. local_setup.sh

$BIN/puppet apply <<PP | tee /tmp/class_not_include-$$
class x {
  notify{'a':}
}
PP
# postcondition - test that the file is empty
# this assumes that we are running at notice level (not debug or verbose)
[ ! -s /tmp/class_not_include-$$ ]
