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

    # This class provides array syntax for using puppet --configprint on a host
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

    # True if this is a pe run, or if the host has had a 'use-service' property set.
    def use_service_scripts?
      is_pe? || self['use-service']
    end

    # Mirrors the true/false value of the host's 'graceful-restarts' property,
    # or falls back to the value of +is_using_passenger?+ if
    # 'graceful-restarts' is nil, but only if this is not a PE run (foss only).
    def graceful_restarts?
      graceful =
      if !self['graceful-restarts'].nil?
        self['graceful-restarts']
      else
        !is_pe? && is_using_passenger?
      end
      graceful
    end

    # Modifies the host settings to indicate that it will be using passenger service scripts,
    # (apache2) by default.  Does nothing if this is a PE host, since it is already using
    # passenger.
    # @param [String] puppetservice Name of the service script that should be
    #   called to stop/startPuppet on this host.  Defaults to 'apache2'.
    def uses_passenger!(puppetservice = 'apache2')
      if !is_pe?
        self['passenger'] = true
        self['puppetservice'] = puppetservice
        self['use-service'] = true
      end
      return true
    end

    # True if this is a PE run, or if the host's 'passenger' property has been set.
    def is_using_passenger?
      is_pe? || self['passenger']
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

    #Examine the host system to determine the architecture
    #@return [Boolean] true if x86_64, false otherwise
    def determine_if_x86_64
      result = exec(Beaker::Command.new("arch | grep x86_64"), :acceptable_exit_codes => (0...127))
      result.exit_code == 0
    end

    #@return [Boolean] true if x86_64, false otherwise
    def is_x86_64?
      @x86_64 ||= determine_if_x86_64
    end

    def connection
      @connection ||= SshConnection.connect( reachable_name,
                                             self['user'],
                                             self['ssh'], { :logger => @logger } )
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

    # Create the provided directory structure on the host
    # @param [String] dir The directory structure to create on the host
    # @return [Boolean] True, if directory construction succeeded, otherwise False
    def mkdir_p dir
      result = exec(Beaker::Command.new("mkdir -p #{dir}"), :acceptable_exit_codes => [0, 1])
      result.exit_code == 0
    end

    # scp files from the localhost to this test host, if a directory is provided it is recursively copied
    # @param source [String] The path to the file/dir to upload
    # @param target [String] The destination path on the host
    # @param [Hash{Symbol=>String}] options Options to alter execution
    # @option options [Array<String>] :ignore An array of file/dir paths that will not be copied to the host
    def do_scp_to source, target, options = {}
      @logger.debug "localhost $ scp #{source} #{@name}:#{target}"

      result = Result.new(@name, [source, target])
      has_ignore = options[:ignore] and not options[:ignore].empty?
      # construct the regex for matching ignored files/dirs
      ignore_re = nil
      if has_ignore
        ignore_arr = Array(options[:ignore]).map do |entry|
          "((\/|\\A)#{entry}(\/|\\z))".sub(/\./, "\.")
        end
        ignore_re = Regexp.new(ignore_arr.join('|'))
      end

      # either a single file, or a directory with no ignores
      if File.file?(source) or (File.directory?(source) and not has_ignore)
        source_file = source
        if has_ignore and (source =~ ignore_re)
          @logger.debug "After rejecting ignored files/dirs, there is no file to copy"
          source_file = nil
          result.stdout = "No files to copy"
          result.exit_code = 1
        end
        if source_file
          result = connection.scp_to(source_file, target, options, $dry_run)
        end
      else # a directory with ignores
        dir_source = Dir.glob("#{source}/**/*").reject do |f|
          f =~ ignore_re
        end
        @logger.debug "After rejecting ignored files/dirs, going to scp [#{dir_source.join(", ")}]"

        # create necessary directory structure on host
        required_dirs = (dir_source.map{ | dir | File.dirname(dir) }).uniq
        require 'pathname'
        source_path = Pathname.new(source)
        required_dirs.each do |dir|
          dir_path = Pathname.new(dir)
          if dir_path.absolute?
            mkdir_p(File.join(target,dir_path.relative_path_from(source_path)))
          else
            mkdir_p( File.join(target, dir) )
          end
        end

        # copy each file to the host
        dir_source.each do |s|
          s_path = Pathname.new(s)
          if s_path.absolute?
            file_path = File.join(target,s_path.relative_path_from(source_path))
          else
            file_path = File.join(target, s)
          end
          result = connection.scp_to(s, file_path, options, $dry_run)
        end
      end

      @logger.debug result.stdout
      return result
    end

    def do_scp_from source, target, options

      @logger.debug "localhost $ scp #{@name}:#{source} #{target}"
      result = connection.scp_from(source, target, options, $dry_run)
      @logger.debug result.stdout
      return result
    end

  end

  [ 'windows', 'unix', 'aix' ].each do |lib|
    require "beaker/host/#{lib}"
  end
end
