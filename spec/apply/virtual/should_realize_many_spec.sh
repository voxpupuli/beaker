#!/bin/bash
#
# test that realize function takes a list.
#
set -e
set -u

. local_setup.sh

HOSTFILE=/tmp/hosts-$$
# precondition:
# /tmp/hosts-$$ should not exist
if [ -e $HOSTFILE ]; then
  rm $HOSTFILE
fi

# puppet code
puppet apply <<PP
@host{'test$$1': ip=>'127.0.0.2', target=>'$HOSTFILE', ensure=>present}
@host{'test$$2': ip=>'127.0.0.2', target=>'$HOSTFILE', ensure=>present}
realize(Host['test$$1'], Host['test$$2'])
PP
# validate - validate that our hostifle contains more than one line that matches test$$
[ $(grep test$$ $HOSTFILE | wc -l) == 2 ]
