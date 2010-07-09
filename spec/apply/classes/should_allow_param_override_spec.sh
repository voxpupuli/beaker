set -e
#
# we are testing that resources declared in a class
# can be applied with an include statement
. local_setup.sh
OUTFILE=/tmp/class_param_use-$$
$BIN/puppet apply <<PP | tee $OUTFILE
class parent {
  notify { 'msg':
    message => parent,
  }
}
class child inherits parent {
  Notify['msg'] {message => 'child'}
}
include parent
include child
PP
grep "defined 'message' as 'child'" $OUTFILE
