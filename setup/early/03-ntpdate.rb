unless options[:notimesync]
  test_name "Update system time sync"
  step "run ntpdate against NTP pool systems"
  hosts.each do |host|
    until on(host, "ping -c 1 us.pool.ntp.org || ping us.pool.ntp.org 16 1 5") do
      sleep 1 
    end
    if host['platform'].include? 'solaris'
      on(host, "ntpdate -w us.pool.ntp.org")
    else
      on(host, "ntpdate -t 5 us.pool.ntp.org")
    end
  end
else
  Log.notify "Skipping ntp time sync"
  skip_test "Skipping ntp time sync"
end
