unless options[:notimesync]
  test_name "Update system time sync"
  step "run ntpdate against NTP pool systems"
  hosts.each do |host|
    if host['platform'].include? 'solaris'
      on(host, "sleep 10 && ntpdate -w #{options[:ntpserver]}")
    else
      on(host, "ntpdate -t 20 #{options[:ntpserver]}")
    end
  end
else
  Log.notify "Skipping ntp time sync"
  skip_test "Skipping ntp time sync"
end
