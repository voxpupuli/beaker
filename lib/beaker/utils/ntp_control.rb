module Beaker
  module Utils
    class NTPControl
      NTPSERVER = 'pool.ntp.org'
      def initialize(options, hosts)
        @options = options.dup
        @hosts = hosts
        @logger = options[:logger]
      end

      def timesync
        @logger.notify "Update system time sync"
        @logger.notify "run ntpdate against NTP pool systems"
        @hosts.each do |host|
          success=false
          if host['platform'].include? 'solaris-10'
            host.exec(Command.new("sleep 10 && ntpdate -w #{NTPSERVER}"))
          elsif host['platform'].include? 'windows'
            # The exit code of 5 is for Windows 2008 systems where the w32tm /register command
            # is not actually necessary.
            host.exec(Command.new("w32tm /register"), :acceptable_exit_codes => [0,5])
            host.exec(Command.new("net start w32time"), :acceptable_exit_codes => [0,2])
            host.exec(Command.new("w32tm /config /manualpeerlist:#{NTPSERVER} /syncfromflags:manual /update"))
            host.exec(Command.new("w32tm /resync"))
          else
            count=0
            until success do
              break if count > 3
              if host.exec(Command.new("ntpdate -t 20 #{NTPSERVER}"), :acceptable_exit_codes => (0..255)).exit_code == 0 
                success=true
              end
              count+=1
            end
            if success
              @logger.notify "NTP date succeeded after #{count} tries"
            else
              @logger.warn "NTP date was not successful after #{count} tries, could cause puppet installation errors"
            end
          end
        end
      rescue => e
        report_and_raise(@logger, e, "timesync (--ntp)")
      end
    end
  end
end
