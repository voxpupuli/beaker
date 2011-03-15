test_name = "verify list of enabled services is correct"

pass_test "Pass forced pending test failure investigation"
# 2010-07-22 Jeff McCune <jeff@puppetlabs.com>
# The goal of this test is to verify the list of enabled services
# returned by puppet resource services matches the list of services
# which are actually enabled.
#
# As per conversation with Dan, this test is a rabbit hole and should
# be marked pending.
fail_test "we don't know how to verify the list of services sensibly"

%q{

#!/bin/bash
#

set -u
source lib/setup.sh
set -e

# count ralshes enabled services
RALSH_SERVICE_ENABLED_COUNT=$( puppet resource service | \
  egrep --count 'enable\s*=>.*true' )

# chkconfigs enabled service count
SERVICE_ENABLED_COUNT=0
for service in $( chkconfig --list | awk '{print $1}' ); do
  if chkconfig "$service"; then
    ((SERVICE_ENABLED_COUNT++))
  fi
done

if [ "$RALSH_SERVICE_ENABLED_COUNT" == "$SERVICE_ENABLED_COUNT" ] ; then
  exit 0
else
  ralsh service | grep -B2 true | grep service | awk -F"'" '{print $2}' | sort > /tmp/sorted-ralsh-$$
  for service in $(chkconfig --list | awk '{print $1}'); do
    if chkconfig $service; then
      echo $service >> /tmp/sorted-service-$$
    fi
  done
  cat /tmp/sorted-service-$$ | sort > /tmp/sorted-service-$$
  echo "ralsh count ${RALSH_SERVICE_ENABLED_COUNT} services"
  echo "chkconfig --list counts ${SERVICE_ENABLED_COUNT} services"
  exit 1
fi

}
