unless options[:notimesync]
  test_name "Update system time sync"
  step "run ntpdate against NTP pool systems"
  on hosts, "ntpdate us.pool.ntp.org"
else
  Log.notify "Skipping ntp time sync"
end
