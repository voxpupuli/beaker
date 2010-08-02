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
echo -e "# Puppet Name: crontest\n* * * * * /bin/true" > ${TMPCRON}

# validation: puppet does not create cron entry and it matches expectation 
(puppet resource cron crontest user=${TMPUSER} command=/bin/true ensure=present hour='0-6' | grep "defined 'hour' as '0-6'") && (crontab -l -u ${TMPUSER} | grep '\* 0-6 \* \* \* /bin/true')
