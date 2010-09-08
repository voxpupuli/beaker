#!/bin/bash
# 
set -e
set -u

source lib/setup.sh

# precondition:
# this cron test unit is not portable 
TMPUSER=cron-$$
TMPFILE=/tmp/cron-$$
if [[ `facter operatingsystem` == 'Ubuntu' ]]; then
  TMPCRON=/var/spool/cron/crontabs/${TMPUSER}
else
  TMPCRON=/var/spool/cron/${TMPUSER}
fi

add_cleanup '{ rm -f ${TMPCRON}; }'
add_cleanup '{ userdel ${TMPUSER}; }'

useradd ${TMPUSER}
rm -f ${TMPCRON}

# validation: puppet create cron entry and it matches expectation 
puppet resource cron crontest user=${TMPUSER} command=/bin/true ensure=present | grep created && crontab -l -u ${TMPUSER} | grep "\* \* \* \* \* /bin/true"
status=$? 
