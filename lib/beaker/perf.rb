module Beaker
  # The Beaker Perf class. A single instance is created per Beaker run.
  class Perf

    PERF_PACKAGES = ['sysstat']
    # SLES does not treat sysstat as a service that can be started
    PERF_SUPPORTED_PLATFORMS = /debian|ubuntu|redhat|centos|oracle|scientific|fedora|el|sles/
    PERF_START_PLATFORMS     = /debian|ubuntu|redhat|centos|oracle|scientific|fedora|el/

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
      if host['platform'] =~ PERF_SUPPORTED_PLATFORMS
        PERF_PACKAGES.each do |pkg|
          if not host.check_for_package pkg
            host.install_package pkg
          end
        end
      else
        @logger.perf_output("Perf (sysstat) not supported on host: " + host)
      end

      if host['platform'] =~ /debian|ubuntu/
        @logger.perf_output("Modify /etc/default/sysstat on Debian and Ubuntu platforms")
        host.exec(Command.new('sed -i s/ENABLED=\"false\"/ENABLED=\"true\"/ /etc/default/sysstat'))
      elsif host['platform'] =~ /sles/
        @logger.perf_output("Creating symlink from /etc/sysstat/sysstat.cron to /etc/cron.d")
        host.exec(Command.new('ln -s /etc/sysstat/sysstat.cron /etc/cron.d'),:acceptable_exit_codes => [0,1])
      end
      if host['platform'] =~ PERF_START_PLATFORMS # SLES doesn't need this step
        host.exec(Command.new('service sysstat start'))
      end
    end

    # Iterate over all hosts, calling get_perf_data
    # @param [void]
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
      if host['platform'] =~ PERF_SUPPORTED_PLATFORMS # All flavours of Linux
        host.exec(Command.new("sar -A -s #{perf_start.strftime("%H:%M:%S")} -e #{perf_end.strftime("%H:%M:%S")}"),:acceptable_exit_codes => [0,1,2])
      else
        @logger.perf_output("Perf (sysstat) not supported on host: " + host)
      end
    end
  end
end
