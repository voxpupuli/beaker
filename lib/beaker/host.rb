require 'socket'
require 'timeout'
require 'benchmark'
require 'rsync'
require 'net/ping'

require 'beaker/dsl/helpers'
require 'beaker/dsl/patterns'

[ 'command', 'ssh_connection'].each do |lib|
  require "beaker/#{lib}"
end

module Beaker
  class Host
    SELECT_TIMEOUT = 30

    include Beaker::DSL::Helpers
    include Beaker::DSL::Patterns

    class CommandFailure < StandardError; end
    class RebootFailure < CommandFailure; end

    # This class provides array syntax for using puppet --configprint on a host
    class PuppetConfigReader
      def initialize(host, command)
        @host = host
        @command = command
      end

      def has_key?(k)
        cmd = PuppetCommand.new(@command, '--configprint all')
        keys = @host.exec(cmd).stdout.split("\n").collect do |x|
          x[/^[^\s]+/]
        end
        keys.include?(k)
      end

      def [](k)
        cmd = PuppetCommand.new(@command, "--configprint #{k.to_s}")
        @host.exec(cmd).stdout.strip
      end
    end

    def self.create name, host_hash, options
      case host_hash['platform']
      when /windows/
        cygwin = host_hash['is_cygwin']
        if cygwin.nil? or cygwin == true
          Windows::Host.new name, host_hash, options
        else
          PSWindows::Host.new name, host_hash, options
        end
      when /aix/
        Aix::Host.new name, host_hash, options
      when /osx/
        Mac::Host.new name, host_hash, options
      when /freebsd/
        FreeBSD::Host.new name, host_hash, options
      when /eos/
        Eos::Host.new name, host_hash, options
      when /cisco/
        Cisco::Host.new name, host_hash, options
      else
        Unix::Host.new name, host_hash, options
      end
    end

    attr_accessor :logger
    attr_reader :name, :host_hash, :options
    def initialize name, host_hash, options
      @logger = host_hash[:logger] || options[:logger]
      @name, @host_hash, @options = name.to_s, host_hash.dup, options.dup

      @host_hash = self.platform_defaults.merge(@host_hash)
      pkg_initialize
    end

    def pkg_initialize
      # This method should be overridden by platform-specific code to
      # handle whatever packaging-related initialization is necessary.
    end

    def node_name
      # TODO: might want to consider caching here; not doing it for now because
      #  I haven't thought through all of the possible scenarios that could
      #  cause the value to change after it had been cached.
      result = puppet_configprint['node_name_value'].strip
    end

    def port_open? port
      begin
        Timeout.timeout SELECT_TIMEOUT do
          TCPSocket.new(reachable_name, port).close
          return true
        end
      rescue Errno::ECONNREFUSED, Timeout::Error, Errno::ETIMEDOUT, Errno::EHOSTUNREACH
        return false
      end
    end

    # Wait for a port on the host.  Useful for those occasions when you've called
    # host.reboot and want to avoid spam from subsequent SSH connections retrying
    # to connect from say retry_on()
    def wait_for_port(port, attempts=15)
      @logger.debug("  Waiting for port #{port} ... ", false)
      start = Time.now
      done = repeat_fibonacci_style_for(attempts) { port_open?(port) }
      if done
        @logger.debug('connected in %0.2f seconds' % (Time.now - start))
      else
        @logger.debug('timeout')
      end
      done
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
    def puppet_configprint(command='agent')
      PuppetConfigReader.new(self, command)
    end
    alias_method :puppet, :puppet_configprint

    def []= k, v
      host_hash[k] = v
    end

    # Does this host have this key?  Either as defined in the host itself, or globally?
    def [] k
      host_hash[k] || options[k]
    end

    # Does this host have this key?  Either as defined in the host itself, or globally?
    def has_key? k
      host_hash.has_key?(k) || options.has_key?(k)
    end

    def delete k
      host_hash.delete(k)
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
      host_hash['vmhostname'] || @name
    end

    def + other
      @name + other
    end

    def is_pe?
      self['type'] && self['type'].to_s =~ /pe/
    end

    def is_cygwin?
      self.class == Windows::Host
    end

    def is_powershell?
      self.class == PSWindows::Host
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
      if host_hash['vmhostname']
        "#{self} (#{@name})"
      else
        self.to_s
      end
    end

    #Determine the ip address of this host
    def get_ip
      @logger.warn("Uh oh, this should be handled by sub-classes but hasn't been")
    end

    # Determine the ip address using logic specific to the hypervisor
    def get_public_ip
      case host_hash[:hypervisor]
      when /^(ec2|openstack)$/
        if self[:hypervisor] == 'ec2' && self[:instance]
          return self[:instance].ip_address
        elsif self[:hypervisor] == 'openstack' && self[:ip]
          return self[:ip]
        else
          # In the case of using ec2 instances with the --no-provision flag, the ec2
          # instance object does not exist and we should just use the curl endpoint
          # specified here:
          # http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-instance-addressing.html
          if self.instance_of?(Windows::Host)
          execute("wget http://169.254.169.254/latest/meta-data/public-ipv4").strip
          else
          execute("curl http://169.254.169.254/latest/meta-data/public-ipv4").strip
          end
        end
      end
    end

    #Return the ip address of this host
    #Always pull fresh, because this can sometimes change
    def ip
      self['ip'] = get_public_ip || get_ip
    end

    #@return [Boolean] true if x86_64, false otherwise
    def is_x86_64?
      @x86_64 ||= determine_if_x86_64
    end

    def connection
      # create new connection object if necessary
      @connection ||= SshConnection.connect( { :ip => self['ip'], :vmhostname => self['vmhostname'], :hostname => @name },
                                             self['user'],
                                             self['ssh'], { :logger => @logger, :ssh_connection_preference => self[:ssh_connection_preference]} )
      # update connection information
      if self['ip'] && (@connection.ip != self['ip'])
        @connection.ip = self['ip']
      end
      if self['vmhostname'] && (@connection.vmhostname != self['vmhostname'])
        @connection.vmhostname = self['vmhostname']
      end
      if @name && (@connection.hostname != @name)
        @connection.hostname = @name
      end
      @connection
    end

    def close
      if @connection
        @connection.close
        # update connection information
        @connection.ip         = self['ip'] if self['ip']
        @connection.vmhostname = self['vmhostname'] if self['vmhostname']
        @connection.hostname   = @name
      end
      @connection = nil
    end

    def exec command, options={}
      result = nil
      # I've always found this confusing
      cmdline = command.cmd_line(self)

      # use the value of :dry_run passed to the method unless
      # undefined, then use parsed @options hash.
      options[:dry_run] ||= @options[:dry_run]

      if options[:dry_run]
        @logger.debug "\n Running in :dry_run mode. Command #{cmdline} not executed."
        result = Beaker::NullResult.new(self, command)
        return result
      end

      if options[:silent]
        output_callback = nil
      else
        @logger.debug "\n#{log_prefix} #{Time.new.strftime('%H:%M:%S')}$ #{cmdline}"
        if @options[:color_host_output]
          output_callback = logger.method(:color_host_output)
        else
          output_callback = logger.method(:host_output)
        end
      end

      unless options[:dry_run]
        # is this returning a result object?
        # the options should come at the end of the method signature (rubyism)
        # and they shouldn't be ssh specific

        seconds = Benchmark.realtime {
          @logger.with_indent do
            result = connection.execute(cmdline, options, output_callback)
          end
        }

        if not options[:silent]
          @logger.debug "\n#{log_prefix} executed in %0.2f seconds" % seconds
        end

        if options[:reset_connection]
          # Expect the connection to fail hard and possibly take a long time timeout.
          # Pre-emptively reset it so we don't wait forever.
          close
          return result
        end

        unless options[:silent]
          # What?
          result.log(@logger)
          if !options[:expect_connection_failure] && !result.exit_code
            # no exit code was collected, so the stream failed
            raise CommandFailure, "Host '#{self}' connection failure running:\n #{cmdline}\nLast #{@options[:trace_limit]} lines of output were:\n#{result.formatted_output(@options[:trace_limit])}"

          end
          if options[:expect_connection_failure] && result.exit_code
            # should have had a connection failure, but didn't
            # wait to see if the connection failure will be generation, otherwise raise error
            if not connection.wait_for_connection_failure(options, output_callback)
              raise CommandFailure,  "Host '#{self}' should have resulted in a connection failure running:\n #{cmdline}\nLast #{@options[:trace_limit]} lines of output were:\n#{result.formatted_output(@options[:trace_limit])}"
            end
          end
          # No, TestCase has the knowledge about whether its failed, checking acceptable
          # exit codes at the host level and then raising...
          # is it necessary to break execution??
          if options[:accept_all_exit_codes] && options[:acceptable_exit_codes]
            @logger.warn ":accept_all_exit_codes & :acceptable_exit_codes set. :acceptable_exit_codes overrides, but they shouldn't both be set at once"
            options[:accept_all_exit_codes] = false
          end
          if !options[:accept_all_exit_codes] && !result.exit_code_in?(Array(options[:acceptable_exit_codes] || [0, nil]))
            raise CommandFailure, "Host '#{self}' exited with #{result.exit_code} running:\n #{cmdline}\nLast #{@options[:trace_limit]} lines of output were:\n#{result.formatted_output(@options[:trace_limit])}"
          end
        end
      end
      result
    end

    # scp files from the localhost to this test host, if a directory is provided it is recursively copied.
    # If the provided source is a directory both the contents of the directory and the directory
    # itself will be copied to the host, if you only want to copy directory contents you will either need to specify
    # the contents file by file or do a separate 'mv' command post scp_to to create the directory structure as desired.
    # To determine if a file/dir is 'ignored' we compare to any contents of the source dir and NOT any part of the path
    # to that source dir.
    #
    # @param source [String] The path to the file/dir to upload
    # @param target_path [String] The destination path on the host
    # @param options [Hash{Symbol=>String}] Options to alter execution
    # @option options [Array<String>] :ignore An array of file/dir paths that will not be copied to the host
    # @example
    #   do_scp_to('source/dir1/dir2/dir3', 'target')
    #   -> will result in creation of target/source/dir1/dir2/dir3 on host
    #
    #   do_scp_to('source/file.rb', 'target', { :ignore => 'file.rb' }
    #   -> will result in not files copyed to the host, all are ignored
    def do_scp_to source, target_path, options
      target = self.scp_path( target_path )

      # use the value of :dry_run passed to the method unless
      # undefined, then use parsed @options hash.
      options[:dry_run] ||= @options[:dry_run]

      if options[:dry_run]
        scp_cmd = "scp #{source} #{@name}:#{target}"
        @logger.debug "\n Running in :dry_run mode. localhost $ #{scp_cmd} not executed."
        return NullResult.new(self, scp_cmd)
      end

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
          result = connection.scp_to(source_file, target, options)
          @logger.trace result.stdout
        end
      else # a directory with ignores
        dir_source = Dir.glob("#{source}/**/*").reject do |f|
          f.gsub(/\A#{Regexp.escape(source)}/, '') =~ ignore_re #only match against subdirs, not full path
        end
        @logger.trace "After rejecting ignored files/dirs, going to scp [#{dir_source.join(", ")}]"

        # create necessary directory structure on host
        # run this quietly (no STDOUT)
        @logger.quiet(true)
        required_dirs = (dir_source.map{ | dir | File.dirname(dir) }).uniq
        require 'pathname'
        required_dirs.each do |dir|
          dir_path = Pathname.new(dir)
          if dir_path.absolute? and (File.dirname(File.absolute_path(source)).to_s != '/')
            mkdir_p(File.join(target, dir.gsub(/#{Regexp.escape(File.dirname(File.absolute_path(source)))}/, '')))
          else
            mkdir_p( File.join(target, dir) )
          end
        end
        @logger.quiet(false)

        # copy each file to the host
        dir_source.each do |s|
          # Copy files, not directories (as they are copied recursively)
          next if File.directory?(s)

          s_path = Pathname.new(s)
          if s_path.absolute? and (File.dirname(File.absolute_path(source)).to_s != '/')
            file_path = File.join(target, File.dirname(s).gsub(/#{Regexp.escape(File.dirname(File.absolute_path(source)))}/,''))
          else
            file_path = File.join(target, File.dirname(s))
          end
          result = connection.scp_to(s, file_path, options)
          @logger.trace result.stdout
        end
      end

      self.scp_post_operations( target, target_path )
      return result
    end

    def do_scp_from source, target, options
      # use the value of :dry_run passed to the method unless
      # undefined, then use parsed @options hash.
      options[:dry_run] ||= @options[:dry_run]

      if options[:dry_run]
        scp_cmd = "scp #{@name}:#{source} #{target}"
        @logger.debug "\n Running in :dry_run mode. localhost $ #{scp_cmd} not executed."
        return  NullResult.new(self, scp_cmd)
      end

      @logger.debug "localhost $ scp #{@name}:#{source} #{target}"
      result = connection.scp_from(source, target, options)
      @logger.debug result.stdout
      return result
    end

    # rsync a file or directory from the localhost to this test host
    # @param from_path [String] The path to the file/dir to upload
    # @param to_path [String] The destination path on the host
    # @param opts [Hash{Symbol=>String}] Options to alter execution
    # @option opts [Array<String>] :ignore An array of file/dir paths that will not be copied to the host
    # @raise [Beaker::Host::CommandFailure] With Rsync error (if available)
    # @return [Rsync::Result] Rsync result with status code
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
      hostname_with_user = "#{user}@#{reachable_name}"

      Rsync.host = hostname_with_user

      # vagrant uses temporary ssh configs in order to use dynamic keys
      # without this config option using ssh may prompt for password
      if ssh_opts[:config] and File.exists?(ssh_opts[:config])
        ssh_args << "-F #{ssh_opts[:config]}"
      else
        if ssh_opts.has_key?('keys') and
            ssh_opts.has_key?('auth_methods') and
            ssh_opts['auth_methods'].include?('publickey')

          # find the first SSH key that exists
          key = Array(ssh_opts['keys']).find do |k|
              File.exist?(k)
          end

          if key
            # rsync doesn't always play nice with tilde, so be sure to expand first
            ssh_args << "-i #{File.expand_path(key)}"
          end
        end
      end

      if ssh_opts.has_key?(:port)
        ssh_args << "-p #{ssh_opts[:port]}"
      end

      # We disable prompt when host isn't known
      ssh_args << "-o 'StrictHostKeyChecking no'"

      if not ssh_args.empty?
        rsync_args << "-e \"ssh #{ssh_args.join(' ')}\""
      end

      if opts.has_key?(:ignore) and not opts[:ignore].empty?
        rsync_args << opts[:ignore].map { |value| "--exclude '#{value}'" }.join(' ')
      end

      # We assume that the *contents* of the directory 'from_path' needs to be
      # copied into the directory 'to_path'
      if File.directory?(from_path) and not from_path.end_with?('/')
        from_path += '/'
      end

      @logger.notify "rsync: localhost:#{from_path} to #{hostname_with_user}:#{to_path} {:ignore => #{opts[:ignore]}}"
      result = Rsync.run(from_path, to_path, rsync_args)
      @logger.debug("rsync returned #{result.inspect}")

      return result if result.success?
      raise Beaker::Host::CommandFailure, result.error
    end

    def ping?
      check = Net::Ping::External.new(self)
      check.ping?
    end

    def down?
      @logger.debug("host.down?: checking if host has gone down using ping...")
      host_up = true
      # give it max 3 minutes to go down, check every 10 seconds
      repeat_for_and_wait 180, 10 do
        host_up = self.ping?
        @logger.debug("- ping result: #{host_up}. Done checking? #{!host_up}")
        !host_up # host down? -> continue looping. up? -> finished
      end
      if host_up
        raise Beaker::Host::RebootFailure, 'Host failed to go down'
      end
      @logger.debug("host.down? host stopped responding, returning true")
      true
    end
  end

  [
    'unix',
    'aix',
    'mac',
    'freebsd',
    'windows',
    'pswindows',
    'eos',
    'cisco',
  ].each do |lib|
    require "beaker/host/#{lib}"
  end
end
