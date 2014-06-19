module Beaker
  # The Beaker Perf module. As there is no state to keep track of, we are only
  # using methods. This may change in the future.
  class Perf

    def initialize( hosts, options, logger )
      @hosts = hosts
      @options = options
      @logger = logger
      @perf_timestamp = Time.now
    end

    def setup_perf_tools
      if @options[:collect_perf_data]
        @hosts.map { |h| setup_perf_on_host(h) }
      end
    end

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

    def print_perf_info()
      if @options[:collect_perf_data]
        @perf_end_timestamp = Time.now
        @hosts.map { |h| get_perf_data(h, @perf_timestamp, @perf_end_timestamp) }
      end
    end

    def get_perf_data(host, perf_start, perf_end)
      @logger.perf_output("Getting perf data for host: " + host)
      if host['platform'] =~ /debian|ubuntu|redhat|centos|sles/
        host.exec(Command.new("sar -A -s #{perf_start.strftime("%H:%M:%S")} -e #{perf_end.strftime("%H:%M:%S")}"))
      end
    end

  end
end
