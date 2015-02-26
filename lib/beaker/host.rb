require 'socket'
require 'timeout'
require 'benchmark'
require 'rsync'

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
        cygwin = options['HOSTS'][name]['is_cygwin']
        if cygwin.nil? or cygwin == true
          Windows::Host.new name, options
        else
          PSWindows::Host.new name, options
        end
      when /aix/
        Aix::Host.new name, options
      when /osx/
        Mac::Host.new name, options
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
      type = @options.get_type
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
      rescue Errno::ECONNREFUSED, Timeout::Error, Errno::ETIMEDOUT
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

    def is_cygwin?
      self['is_cygwin'] == nil || self['is_cygwin'] == true
    end

    def platform
      self['platform']
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
      if is_cygwin?
        if self[:platform] =~ /osx|solaris/
          result = exec(Beaker::Command.new("uname -a | grep x86_64"), :acceptable_exit_codes => (0...127))
          result.exit_code == 0
        else
          result = exec(Beaker::Command.new("arch | grep x86_64"), :acceptable_exit_codes => (0...127))
          result.exit_code == 0
        end
      else
        result = exec(Beaker::Command.new("wmic os get osarchitecture"), :acceptable_exit_codes => (0...127))
        result.stdout =~ /64/
      end
    end

    #@return [Boolean] true if x86_64, false otherwise
    def is_x86_64?
      @x86_64 ||= determine_if_x86_64
    end

    #Add the provided key/val to the current ssh environment
    #@param [String] key The key to add the value to
    #@param [String] val The value for the key
    #@example
    #  host.add_env_var('PATH', '/usr/bin:PATH')
    def add_env_var key, val
      key = key.to_s.upcase
      if self.is_cygwin?
        escaped_val = Regexp.escape(val).gsub('/', '\/').gsub(';', '\;')
        env_file = self[:ssh_env_file]
        #see if the key/value pair already exists
        if exec(Beaker::Command.new("grep #{key}=.*#{escaped_val} #{env_file}"), :acceptable_exit_codes => (0..255) ).exit_code == 0
          return #nothing to do here, key value pair already exists
        #see if the key already exists
        elsif exec(Beaker::Command.new("grep #{key} #{env_file}"), :acceptable_exit_codes => (0..255) ).exit_code == 0
          exec(Beaker::SedCommand.new(self['platform'], "s/#{key}=/#{key}=#{escaped_val}:/", env_file))
        else
          exec(Beaker::Command.new("echo \"#{key}=#{val}\" >> #{env_file}"))
        end
      else #powershell windows
        #see if the key/value pair already exists
        result = exec(Beaker::Command.new("set #{key}"), :acceptable_exit_codes => (0..255))
        subbed_result = result.stdout.chomp
        if result.exit_code == 0
          subbed_result = subbed_result.gsub(/#{Regexp.escape(val.gsub(/'|"/, ''))}/, '')
        end
        #not present, add it
        if subbed_result == result.stdout.chomp
          exec(Beaker::Command.new("setx /M #{key} %#{key}%;#{val}"))
          exec(Beaker::Command.new("set #{key}=%#{key}%;#{val}"))
        end
      end
    end

    #Return the value of a specific env var
    #@param [String] key The key to look for
    #@example
    #  host.get_env_var('path')
    def get_env_var key
      key = key.to_s.upcase
      exec(Beaker::Command.new("env | grep #{key}"), :acceptable_exit_codes => (0..255)).stdout.chomp
    end

    #Delete the provided key/val from the current ssh environment
    #@param [String] key The key to delete the value from
    #@param [String] val The value to delete for the key
    #@example
    #  host.delete_env_var('PATH', '/usr/bin:PATH')
    def delete_env_var key, val
      key = key.to_s.upcase
      if self.is_cygwin?
        val = Regexp.escape(val).gsub('/', '\/').gsub(';', '\;')
        #if the key only has that single value remove the entire line
        exec(Beaker::SedCommand.new(self['platform'], "/#{key}=#{val}$/d", self[:ssh_env_file]))
        #value in middle of list
        exec(Beaker::SedCommand.new(self['platform'], "s/#{key}=\\(.*\\)[;:]#{val}/#{key}=\\1/", self[:ssh_env_file]))
        #value in start of list
        exec(Beaker::SedCommand.new(self['platform'], "s/#{key}=#{val}[;:]/#{key}=/", self[:ssh_env_file]))
      else #powershell windows
        #get the current value of the key
        result = exec(Beaker::Command.new("set #{key}"), :acceptable_exit_codes => (0..255))
        subbed_result = result.stdout.chomp
        if result.exit_code == 0
          subbed_result = subbed_result.gsub(/#{Regexp.escape(val.gsub(/'|"/, ''))}/, '')
        end
        if subbed_result != result
          #set to the truncated value
          self.add_env_var(key, subbed_result)
        end
      end
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
          if !options[:accept_all_exit_codes] && !result.exit_code_in?(Array(options[:acceptable_exit_codes] || 0))
            raise CommandFailure, "Host '#{self}' exited with #{result.exit_code} running:\n #{cmdline}\nLast #{@options[:trace_limit]} lines of output were:\n#{result.formatted_output(@options[:trace_limit])}"
          end
        end
        # Danger, so we have to return this result?
        result
      end
    end

    # Recursively remove the path provided
    # @param [String] path The path to remove
    def rm_rf path
      exec(Beaker::Command.new("rm -rf #{path}"))
    end

    # Create the provided directory structure on the host
    # @param [String] dir The directory structure to create on the host
    # @return [Boolean] True, if directory construction succeeded, otherwise False
    def mkdir_p dir
      if self.is_cygwin?
        cmd = "mkdir -p #{dir}"
      else
        cmd = "if not exist #{dir.gsub!('/','\\')} (md #{dir.gsub!('/','\\')})"
      end

      result = exec(Beaker::Command.new(cmd), :acceptable_exit_codes => [0, 1])
      result.exit_code == 0
    end

    # scp files from the localhost to this test host, if a directory is provided it is recursively copied
    # @param source [String] The path to the file/dir to upload
    # @param target [String] The destination path on the host
    # @param options [Hash{Symbol=>String}] Options to alter execution
    # @option options [Array<String>] :ignore An array of file/dir paths that will not be copied to the host
    def do_scp_to source, target, options
      @logger.notify "localhost $ scp #{source} #{@name}:#{target} {:ignore => #{options[:ignore]}}"

      result = Result.new(@name, [source, target])
      has_ignore = options[:ignore] and not options[:ignore].empty?
      # construct the regex for matching ignored files/dirs
      ignore_re = nil
      if has_ignore
        ignore_arr = Array(options[:ignore]).map do |entry|
          "((\/|\\A)#{Regexp.escape(entry)}(\/|\\z))"
        end
        ignore_re = Regexp.new(ignore_arr.join('|'))
        @logger.debug("going to ignore #{ignore_re}")
      end

      # either a single file, or a directory with no ignores
      if not File.file?(source) and not File.directory?(source)
        raise IOError, "No such file or directory - #{source}"
      end
      if File.file?(source) or (File.directory?(source) and not has_ignore)
        source_file = source
        if has_ignore and (source =~ ignore_re)
          @logger.trace "After rejecting ignored files/dirs, there is no file to copy"
          source_file = nil
          result.stdout = "No files to copy"
          result.exit_code = 1
        end
        if source_file
          result = connection.scp_to(source_file, target, options, $dry_run)
          @logger.trace result.stdout
        end
      else # a directory with ignores
        dir_source = Dir.glob("#{source}/**/*").reject do |f|
          f =~ ignore_re
        end
        @logger.trace "After rejecting ignored files/dirs, going to scp [#{dir_source.join(", ")}]"

        # create necessary directory structure on host
        # run this quietly (no STDOUT)
        #@logger.quiet(true)
        required_dirs = (dir_source.map{ | dir | File.dirname(dir) }).uniq
        require 'pathname'
        required_dirs.each do |dir|
          dir_path = Pathname.new(dir)
          if dir_path.absolute?
            mkdir_p(File.join(target, dir.gsub(/#{Regexp.escape(File.dirname(File.absolute_path(source)))}/, '')))
          else
            mkdir_p( File.join(target, dir) )
          end
        end
        #@logger.quiet(false)

        # copy each file to the host
        dir_source.each do |s|
          s_path = Pathname.new(s)
          if s_path.absolute?
            file_path = File.join(target, File.dirname(s).gsub(/#{Regexp.escape(File.dirname(File.absolute_path(source)))}/,''))
          else
            file_path = File.join(target, File.dirname(s))
          end
          result = connection.scp_to(s, file_path, options, $dry_run)
          @logger.trace result.stdout
        end
      end

      return result
    end

    def do_scp_from source, target, options

      @logger.debug "localhost $ scp #{@name}:#{source} #{target}"
      result = connection.scp_from(source, target, options, $dry_run)
      @logger.debug result.stdout
      return result
    end

    # rsync a file or directory from the localhost to this test host
    # @param from_path [String] The path to the file/dir to upload
    # @param to_path [String] The destination path on the host
    # @param opts [Hash{Symbol=>String}] Options to alter execution
    # @option opts [Array<String>] :ignore An array of file/dir paths that will not be copied to the host
    def do_rsync_to from_path, to_path, opts = {}
      ssh_opts = self['ssh']
      rsync_args = []
      ssh_args = []

      if not File.file?(from_path) and not File.directory?(from_path)
        raise IOError, "No such file or directory - #{from_path}"
      end

      # We enable achieve mode and compression
      rsync_args << "-az"

      if not self['user']
        user = "root"
      else
        user = self['user']
      end
      hostname_with_user = "#{user}@#{self}"

      Rsync.host = hostname_with_user

      if ssh_opts.has_key?('keys') and
        ssh_opts.has_key?('auth_methods') and
        ssh_opts['auth_methods'].include?('publickey')

        key = ssh_opts['keys']

        # If an array was set, then we use the first value
        if key.is_a? Array
          key = key.first
        end

        # We need to expand tilde manually as rsync can be
        # funny sometimes
        key = File.expand_path(key)

        ssh_args << "-i #{key}"
      end

      if ssh_opts.has_key?('port') and
        ssh_args << "-p #{ssh_opts['port']}"
      end

      # We disable prompt when host isn't known
      ssh_args << "-o 'StrictHostKeyChecking no'"

      if not ssh_args.empty?
        rsync_args << "-e \"ssh #{ssh_args.join(' ')}\""
      end

      if opts.has_key?(:ignore) and not opts[:ignore].empty?
        opts[:ignore].map! do |value|
          "--exclude '#{value}'"
        end
        rsync_args << opts[:ignore].join(' ')
      end

      # We assume that the *contents* of the directory 'from_path' needs to be
      # copied into the directory 'to_path'
      if File.directory?(from_path) and not from_path.end_with?('/')
        from_path += '/'
      end

      @logger.notify "rsync: localhost:#{from_path} to #{hostname_with_user}:#{to_path} {:ignore => #{opts[:ignore]}}"
      result = Rsync.run(from_path, to_path, rsync_args)
      result
    end

  end

  [ 'windows', 'pswindows', 'unix', 'aix', 'mac' ].each do |lib|
    require "beaker/host/#{lib}"
  end
end
