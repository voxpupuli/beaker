unless options[:notimesync]
  test_name "Update system time sync"
  step "run ntpdate against NTP pool systems"
  hosts.each do |host|
    if host['platform'].include? 'solaris'
      on(host, "sleep 10 && ntpdate -w ntp.puppetlabs.lan")
    else
      on(host, "ntpdate -t 20 ntp.puppetlabs.lan")
    end
  end
else
  Log.notify "Skipping ntp time sync"
  skip_test "Skipping ntp time sync"
end
