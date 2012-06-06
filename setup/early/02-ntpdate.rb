if options[:timesync]
  test_name "Update system time sync"
  step "run ntpdate against NTP pool systems"
  hosts.each do |host|
    success=FALSE
    if host['platform'].include? 'solaris'
      on(host, "sleep 10 && ntpdate -w #{options[:ntpserver]}")
    elsif host['platform'].include? 'windows'
      # The exit code of 5 is for Windows 2008 systems where the w32tm /register command
      # is not actually necessary.
      on(host, "w32tm /register", :acceptable_exit_codes => [0,5])
      on(host, "net start w32time", :acceptable_exit_codes => [0,2])
      on(host, "w32tm /config /manualpeerlist:#{options[:ntpserver]} /syncfromflags:manual /update")
      on(host, "w32tm /resync")
    else
      count=0
      until success do
        count+=1
        skip_test "ntp time sync failed after #{count} tries" and break if count > 3
        on(host, "ntpdate -t 20 #{options[:ntpserver]}") do
          success=TRUE if exit_code == 0
        end
      end
      logger.notify "NTP date succeeded after #{count} tries"
    end
  end
else
  logger.notify "Skipping ntp time sync"
  skip_test "Skipping ntp time sync"
end
