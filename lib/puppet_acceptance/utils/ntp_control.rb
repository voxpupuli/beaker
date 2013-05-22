module PuppetAcceptance
  class NTPController
    def initialize(options, hosts)
      @options = options.dup
      @hosts = hosts
      @logger = options[:logger]
    end

    def timesync
      @logger.debug "Update system time sync"
      @logger.debug "run ntpdate against NTP pool systems"
      @hosts.each do |host|
        success=FALSE
        if host['platform'].include? 'solaris-10'
          host.exec(HostCommand.new("sleep 10 && ntpdate -w #{@options[:ntpserver]}"))
        elsif host['platform'].include? 'windows'
          # The exit code of 5 is for Windows 2008 systems where the w32tm /register command
          # is not actually necessary.
          host.exec(HostCommand.new("w32tm /register"), :acceptable_exit_codes => [0,5])
          host.exec(HostCommand.new("net start w32time"), :acceptable_exit_codes => [0,2])
          host.exec(HostCommand.new("w32tm /config /manualpeerlist:#{@options[:ntpserver]} /syncfromflags:manual /update"))
          host.exec(HostCommand.new("w32tm /resync"))
        else
          count=0
          until success do
            count+=1
            raise "ntp time sync failed after #{count} tries" and break if count > 3
            if host.exec(HostCommand.new("ntpdate -t 20 #{@options[:ntpserver]}")).exit_code == 0 
              success=TRUE 
            end
          end
          @logger.notify "NTP date succeeded after #{count} tries"
        end
      end

    end
  end
end
