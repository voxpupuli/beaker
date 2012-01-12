unless options[:notimesync]
  test_name "Update system time sync"
  step "run ntpdate against NTP pool systems"
  hosts.each do |host|
    success=FALSE
    if host['platform'].include? 'solaris'
      on(host, "sleep 10 && ntpdate -w #{options[:ntpserver]}")
    else
      count=0
      until success do
        count+=1
        skip_test "ntp time sync failed after #{count} tries" and break if count > 3
        on(host, "ntpdate -t 20 #{options[:ntpserver]}") do
          success=TRUE if exit_code == 0
        end
      end
      Log.notify "NTP date succeeded after #{count} tries"
    end
  end
else
  Log.notify "Skipping ntp time sync"
  skip_test "Skipping ntp time sync"
end
