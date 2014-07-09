module Beaker
  # The Beaker Perf class. A single instance is created per Beaker run.
  class Perf

    # Create the Perf instance and runs setup_perf_on_host on all hosts if --collect-perf-data
    # was used as an option on the Baker command line invocation. Instances of this class do not
    # hold state and its methods are helpers for remotely executing tasks for performance data
    # gathering with sysstat/sar
    #
    # @param [Array<Host>] hosts All from the configuration
    # @param [Hash] options Options to alter execution
    # @param [Logger] logger The options hash doesn't contain a reference at this point, so we need
    #                        one here
    # @return [void]
    def initialize( hosts, options, logger )
      @hosts = hosts
      @options = options
      @logger = logger
      @collect_perf_data = @options[:collect_perf_data]
      @perf_timestamp = Time.now
      if @collect_perf_data
        @hosts.map { |h| setup_perf_on_host(h) }
      end
    end

    # Some systems need special modification to make sysstat work. This is done here.
    # @param [Host] host The host we are working with
    # @return [void]
    def setup_perf_on_host(host)
      @logger.perf_output("Setup perf on host: " + host)
      if host['platform'] =~ /debian|ubuntu/
        @logger.perf_output("Modify /etc/default/sysstat on Debian and Ubuntu platforms")
        host.exec(Command.new('sed -i s/ENABLED=\"false\"/ENABLED=\"true\"/ /etc/default/sysstat'))
      elsif host['platform'] =~ /sles/
        @logger.perf_output("Creating symlink from /etc/sysstat/sysstat.cron to /etc/cron.d")
        host.exec(Command.new('ln -s /etc/sysstat/sysstat.cron /etc/cron.d'),:acceptable_exit_codes => [0,1])
      end
      if host['platform'] =~ /debian|ubuntu|redhat|centos/ # SLES doesn't need this step
        host.exec(Command.new('service sysstat start'))
      end
    end

    # If :collect_perf_data is true, iterate over all hosts, calling get_perf_data
    # @param [void]
    # @return [void]
    def print_perf_info()
      if @collect_perf_data
        @perf_end_timestamp = Time.now
        @hosts.map { |h| get_perf_data(h, @perf_timestamp, @perf_end_timestamp) }
      end
    end

    # If host is a supported (ie linux) platform, generate a performance report
    # @param [Host] host The host we are working with
    # @param [Time] perf_start The beginning time for the SAR report
    # @param [Time] perf_end   The ending time for the SAR report
    # @return [void]  The report is sent to the logging output
    def get_perf_data(host, perf_start, perf_end)
      @logger.perf_output("Getting perf data for host: " + host)
      if host['platform'] =~ /debian|ubuntu|redhat|centos|sles/
        host.exec(Command.new("sar -A -s #{perf_start.strftime("%H:%M:%S")} -e #{perf_end.strftime("%H:%M:%S")}"))
      end
    end
  end
end
