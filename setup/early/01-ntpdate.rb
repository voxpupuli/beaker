test_name "Update system time sync"
step "run ntpdate against NTP pool systems"
on hosts, "ntpdate pool.us.ntp.org"
