require 'socket'
require 'timeout'
require 'benchmark'

[ 'command', 'ssh_connection' ].each do |lib|
  require "beaker/#{lib}"
end

module Beaker
  class Host
    SELECT_TIMEOUT = 30

    class CommandFailure < StandardError; end

    # This class providers array syntax for using puppet --configprint on a host
    class PuppetConfigReader
      def initialize(host, command)
        @host = host
        @command = command
      end

      def [](k)
        cmd = PuppetCommand.new(@command, "--configprint #{k.to_s}")
        @host.exec(cmd).stdout.strip
      end
    end

    def self.create name, options
      case options['HOSTS'][name]['platform']
      when /windows/
        Windows::Host.new name, options
      when /aix/
        Aix::Host.new name, options
      else
        Unix::Host.new name, options
      end
    end

    attr_accessor :logger
    attr_reader :name, :defaults
    def initialize name, options
      @logger = options[:logger]
      @name, @options = name.to_s, options.dup

      # This is annoying and its because of drift/lack of enforcement/lack of having
      # a explict relationship between our defaults, our setup steps and how they're
      # related through 'type' and the differences between the assumption of our two
      # configurations we have for many of our products
      type = is_pe? ? :pe : :foss
      @defaults = merge_defaults_for_type @options, type
      pkg_initialize
    end

    def pkg_initialize
      # This method should be overridden by platform-specific code to
      # handle whatever packaging-related initialization is necessary.
    end

    def merge_defaults_for_type options, type
      defaults = self.class.send "#{type}_defaults".to_sym
      defaults.merge(options.merge((options['HOSTS'][name])))
    end

    def node_name
      # TODO: might want to consider caching here; not doing it for now because
      #  I haven't thought through all of the possible scenarios that could
      #  cause the value to change after it had been cached.
      result = puppet['node_name_value'].strip
    end

    def port_open? port
      begin
        Timeout.timeout SELECT_TIMEOUT do
          TCPSocket.new(reachable_name, port).close
          return true
        end
      rescue Errno::ECONNREFUSED, Timeout::Error
        return false
      end
    end

    def up?
      begin
        Socket.getaddrinfo( reachable_name, nil )
        return true
      rescue SocketError
        return false
      end
    end

    # Return the preferred method to reach the host, will use IP is available and then default to {#hostname}.
    def reachable_name
      self['ip'] || hostname
    end

    # Returning our PuppetConfigReader here allows users of the Host
    # class to do things like `host.puppet['vardir']` to query the
    # 'main' section or, if they want the configuration for a
    # particular run type, `host.puppet('agent')['vardir']`
    def puppet(command='agent')
      PuppetConfigReader.new(self, command)
    end

    def []= k, v
      @defaults[k] = v
    end

    def [] k
      @defaults[k]
    end

    def has_key? k
      @defaults.has_key?(k)
    end

    # The {#hostname} of this host.
    def to_str
      hostname
    end

    # The {#hostname} of this host.
    def to_s
      hostname
    end

    # Return the public name of the particular host, which may be different then the name of the host provided in
    # the configuration file as some provisioners create random, unique hostnames.
    def hostname
      @defaults['vmhostname'] || @name
    end

    def + other
      @name + other
    end

    def is_pe?
      @options.is_pe?
    end

    def log_prefix
      if @defaults['vmhostname']
        "#{self} (#{@name})"
      else
        self.to_s
      end
    end

    #Determine the ip address of this host
    def get_ip
      @logger.warn("Uh oh, this should be handled by sub-classes but hasn't been")
    end

    #Return the ip address of this host
    def ip
      self[:ip] ||= get_ip
    end

    def connection
      @connection ||= SshConnection.connect( reachable_name,
                                             self['user'],
                                             self['ssh'] )
    end

    def close
      @connection.close if @connection
      @connection = nil
    end

    def exec command, options={}
      # I've always found this confusing
      cmdline = command.cmd_line(self)

      if options[:silent]
        output_callback = nil
      else
        @logger.debug "\n#{log_prefix} #{Time.new.strftime('%H:%M:%S')}$ #{cmdline}"
        output_callback = logger.method(:host_output)
      end

      unless $dry_run
        # is this returning a result object?
        # the options should come at the end of the method signature (rubyism)
        # and they shouldn't be ssh specific
        result = nil

        seconds = Benchmark.realtime {
          result = connection.execute(cmdline, options, output_callback)
        }

        if not options[:silent]
          @logger.debug "\n#{log_prefix} executed in %0.2f seconds" % seconds
        end

        unless options[:silent]
          # What?
          result.log(@logger)
          # No, TestCase has the knowledge about whether its failed, checking acceptable
          # exit codes at the host level and then raising...
          # is it necessary to break execution??
          unless result.exit_code_in?(Array(options[:acceptable_exit_codes] || 0))
            raise CommandFailure, "Host '#{self}' exited with #{result.exit_code} running:\n #{cmdline}\nLast #{@options[:trace_limit]} lines of output were:\n#{result.formatted_output(@options[:trace_limit])}"
          end
        end
        # Danger, so we have to return this result?
        result
      end
    end

    def do_scp_to source, target, options
      @logger.debug "localhost $ scp #{source} #{@name}:#{target} #{options.to_s}"
      result = connection.scp_to(source, target, options, $dry_run)
      return result
    end

    def do_scp_from source, target, options

      @logger.debug "localhost $ scp #{@name}:#{source} #{target} #{options.to_s}"
      result = connection.scp_from(source, target, options, $dry_run)
      return result
    end

  end

  [ 'windows', 'unix', 'aix' ].each do |lib|
    require "beaker/host/#{lib}"
  end
end
