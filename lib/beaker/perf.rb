module Beaker
  # The Beaker Perf class. A single instance is created per Beaker run.
  class Perf

    PERF_PACKAGES = ['sysstat']
    # SLES does not treat sysstat as a service that can be started
    PERF_SUPPORTED_PLATFORMS = /debian|ubuntu|redhat|centos|oracle|scientific|fedora|el|eos|cumulus|opensuse|sles/
    PERF_START_PLATFORMS     = /debian|ubuntu|redhat|centos|oracle|scientific|fedora|el|eos|cumulus/

    # Create the Perf instance and runs setup_perf_on_host on all hosts if --collect-perf-data
    # was used as an option on the Baker command line invocation. Instances of this class do not
    # hold state and its methods are helpers for remotely executing tasks for performance data
    # gathering with sysstat/sar
    #
    # @param [Array<Host>] hosts All from the configuration
    # @param [Hash] options Options to alter execution
    # @return [void]
    def initialize( hosts, options )
      @hosts = hosts
      @options = options
      @logger = options[:logger]
      @perf_timestamp = Time.now
      @hosts.map { |h| setup_perf_on_host(h) }
    end

    # Install sysstat if required and perform any modifications needed to make sysstat work.
    # @param [Host] host The host we are working with
    # @return [void]
    def setup_perf_on_host(host)
      @logger.perf_output("Setup perf on host: " + host)
      # Install sysstat if required
      if PERF_SUPPORTED_PLATFORMS.match?(host['platform'])
        PERF_PACKAGES.each do |pkg|
          if not host.check_for_package pkg
            host.install_package pkg
          end
        end
      else
        @logger.perf_output("Perf (sysstat) not supported on host: " + host)
      end

      if /debian|ubuntu|cumulus/.match?(host['platform'])
        @logger.perf_output("Modify /etc/default/sysstat on Debian and Ubuntu platforms")
        host.exec(Command.new('sed -i s/ENABLED=\"false\"/ENABLED=\"true\"/ /etc/default/sysstat'))
      elsif /opensuse|sles/.match?(host['platform'])
        @logger.perf_output("Creating symlink from /etc/sysstat/sysstat.cron to /etc/cron.d")
        host.exec(Command.new('ln -s /etc/sysstat/sysstat.cron /etc/cron.d'),:acceptable_exit_codes => [0,1])
      end
      if @options[:collect_perf_data]&.include?('aggressive')
        @logger.perf_output("Enabling aggressive sysstat polling")
        if /debian|ubuntu/.match?(host['platform'])
          host.exec(Command.new('sed -i s/5-55\\\/10/*/ /etc/cron.d/sysstat'))
        elsif /centos|el|fedora|oracle|redhat|scientific/.match?(host['platform'])
          host.exec(Command.new('sed -i s/*\\\/10/*/ /etc/cron.d/sysstat'))
        end
      end
      if PERF_START_PLATFORMS.match?(host['platform']) # SLES doesn't need this step
        host.exec(Command.new('service sysstat start'))
      end
    end

    # Iterate over all hosts, calling get_perf_data
    # @return [void]
    def print_perf_info()
      @perf_end_timestamp = Time.now
      @hosts.map { |h| get_perf_data(h, @perf_timestamp, @perf_end_timestamp) }
    end

    # If host is a supported (ie linux) platform, generate a performance report
    # @param [Host] host The host we are working with
    # @param [Time] perf_start The beginning time for the SAR report
    # @param [Time] perf_end   The ending time for the SAR report
    # @return [void]  The report is sent to the logging output
    def get_perf_data(host, perf_start, perf_end)
      @logger.perf_output("Getting perf data for host: " + host)
      if PERF_SUPPORTED_PLATFORMS.match?(host['platform']) # All flavours of Linux
        if not @options[:collect_perf_data]&.include?('aggressive')
          host.exec(Command.new("sar -A -s #{perf_start.strftime("%H:%M:%S")} -e #{perf_end.strftime("%H:%M:%S")}"),:acceptable_exit_codes => [0,1,2])
        end
        if (defined? @options[:graphite_server] and not @options[:graphite_server].nil?) and
           (defined? @options[:graphite_perf_data] and not @options[:graphite_perf_data].nil?)
          export_perf_data_to_graphite(host)
        end
      else
        @logger.perf_output("Perf (sysstat) not supported on host: " + host)
      end
    end

    # Send performance report numbers to an external Graphite instance
    # @param [Host] host The host we are working with
    # @return [void]  The report is sent to the logging output
    def export_perf_data_to_graphite(host)
      @logger.perf_output("Sending data to Graphite server: " + @options[:graphite_server])

      data = JSON.parse(host.exec(Command.new("sadf -j -- -A"),:silent => true).stdout)
      hostname = host['vmhostname'].split('.')[0]

      data['sysstat']['hosts'].each do |host|
        host['statistics'].each do |poll|
          timestamp = DateTime.parse(poll['timestamp']['date'] + ' ' + poll['timestamp']['time']).to_time.to_i

          poll.keys.each do |stat|
            case stat
              when 'cpu-load-all'
                poll[stat].each do |s|
                  s.keys.each do |k|
                    next if k == 'cpu'

                    socket = TCPSocket.new(@options[:graphite_server], 2003)
                    socket.puts "#{@options[:graphite_perf_data]}.#{hostname}.cpu.#{s['cpu']}.#{k} #{s[k]} #{timestamp}"
                    socket.close
                  end
                end

              when 'memory'
                poll[stat].keys.each do |s|
                  socket = TCPSocket.new(@options[:graphite_server], 2003)
                  socket.puts "#{@options[:graphite_perf_data]}.#{hostname}.memory.#{s} #{poll[stat][s]} #{timestamp}"
                  socket.close
                end
            end
          end
        end
      end
    end
  end
end
