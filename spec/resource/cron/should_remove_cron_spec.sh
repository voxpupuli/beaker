#!/bin/bash
set -e
set -u

source lib/setup.sh

TMPUSER=cron-$$
TMPFILE=/tmp/cron-$$
# other operating systems my store their crons in a different location
# not sure this is the best general way to handle testing across multiple OS's
# but it seems reasonable in this test case
if [[ `facter operatingsystem` == 'Ubuntu' ]]; then
  TMPCRON=/var/spool/cron/crontabs/${TMPUSER}
else
  TMPCRON=/var/spool/cron/${TMPUSER}
fi

add_cleanup '{ rm -f ${TMPCRON}; }'
add_cleanup '{ userdel ${TMPUSER}; }'

useradd ${TMPUSER}
echo -e "# Puppet Name: crontest\n* * * * * /bin/true" > ${TMPCRON}

# validation: puppet does not create cron entry and it matches expectation
(puppet resource cron crontest user=${TMPUSER} command=/bin/true ensure=absent | grep removed ) && ((`crontab -l -u ${TMPUSER} | grep -c /bin/true` == 0))
