require 'socket'
require 'timeout'

%w(command ssh_connection).each do |lib|
  begin
    require "beaker/#{lib}"
  rescue LoadError
    require File.expand_path(File.join(File.dirname(__FILE__), lib))
  end
end

module Beaker
  class Host

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
        Timeout.timeout 10 do
          TCPSocket.new(reachable_name, port).close
          return true
        end
      rescue Errno::ECONNREFUSED, Timeout::Error
        return false
      end
    end

    def up?
      require 'socket'
      begin
        Socket.getaddrinfo( reachable_name, nil )
        return true
      rescue SocketError
        return false
      end
    end

    def reachable_name
      self['ip'] || self['vmhostname'] || name
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

    def to_str
      @defaults['vmhostname'] || @name
    end

    def to_s
      @defaults['vmhostname'] || @name
    end

    def + other
      @name + other
    end

    def is_pe?
      @options.is_pe?
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
        if @defaults['vmhostname']
          @logger.debug "\n#{self} (#{@name}) $ #{cmdline}"
        else
          @logger.debug "\n#{self} $ #{cmdline}"
        end
        output_callback = logger.method(:host_output)
      end

      unless $dry_run
        # is this returning a result object?
        # the options should come at the end of the method signature (rubyism)
        # and they shouldn't be ssh specific
        result = connection.execute(cmdline, options, output_callback)

        unless options[:silent]
          # What?
          result.log(@logger)
          # No, TestCase has the knowledge about whether its failed, checking acceptable
          # exit codes at the host level and then raising...
          # is it necessary to break execution??
          unless result.exit_code_in?(Array(options[:acceptable_exit_codes] || 0))
            limit = 10
            raise "Host '#{self}' exited with #{result.exit_code} running:\n #{cmdline}\nLast #{limit} lines of output were:\n#{result.formatted_output(limit)}"
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

  require File.expand_path(File.join(File.dirname(__FILE__), 'host/windows'))
  require File.expand_path(File.join(File.dirname(__FILE__), 'host/unix'))
  require File.expand_path(File.join(File.dirname(__FILE__), 'host/aix'))
end
