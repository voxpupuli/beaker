#!/bin/bash

set -e
set -u
# PRECONDITION
. local_setup.sh
GROUP=bozo$$ 
if getent group $GROUP; then
  groupdel bozo
fi
# TEST
$BIN/puppet resource group $GROUP ensure=absent > $OUTFILE
# VALIDATE
! grep "notice: /Group[$GROUP]/ensure: removed" $OUTFILE
