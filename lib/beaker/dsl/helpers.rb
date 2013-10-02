require 'resolv'
require 'inifile'
require 'timeout'
require 'beaker/dsl/outcomes'

module Beaker
  module DSL
    # This is the heart of the Puppet Acceptance DSL. Here you find a helper
    # to proxy commands to hosts, more commands to move files between hosts
    # and execute remote scripts, confine test cases to certain hosts and
    # prepare the state of a test case.
    #
    # To mix this is into a class you need the following:
    # * a method *hosts* that yields any hosts implementing
    #   {Beaker::Host}'s interface to act upon.
    # * a method *logger* that yields a logger implementing
    #   {Beaker::Logger}'s interface.
    #
    #
    # @api dsl
    module Helpers
      # @!macro common_opts
      #   @param [Hash{Symbol=>String}] opts Options to alter execution.
      #   @option opts [Boolean] :silent (false) Do not produce log output
      #   @option opts [Array<Fixnum>] :acceptable_exit_codes ([0]) An array
      #     (or range) of integer exit codes that should be considered
      #     acceptable.  An error will be thrown if the exit code does not
      #     match one of the values in this list.
      #   @option opts [Hash{String=>String}] :environment ({}) These will be
      #     treated as extra environment variables that should be set before
      #     running the command.
      #

      # The primary method for executing commands *on* some set of hosts.
      #
      # @param [Host, Array<Host>] host    One or more hosts to act upon.
      # @param [String, Command]   command The command to execute on *host*.
      # @param [Proc]              block   Additional actions or assertions.
      # @!macro common_opts
      #
      # @example Most basic usage
      #     on hosts, 'ls /tmp'
      #
      # @example Allowing additional exit codes to pass
      #     on agents, 'puppet agent -t', :acceptable_exit_codes => [0,2]
      #
      # @example Using the returned result for any kind of checking
      #     if on(host, 'ls -la ~').stdout =~ /\.bin/
      #       ...do some action...
      #     end
      #
      # @example Using TestCase helpers from within a test.
      #     agents.each do |agent|
      #       on agent, 'cat /etc/puppet/puppet.conf' do
      #         assert_match stdout, /server = #{master}/, 'WTF Mate'
      #       end
      #     end
      #
      # @return [Result]   An object representing the outcome of *command*.
      # @raise  [FailTest] Raises an exception if *command* obviously fails.
      def on(host, command, opts = {}, &block)
        unless command.is_a? Command
          cmd_opts = opts[:environment] ? { 'ENV' => opts.delete(:environment) } : Hash.new
          command = Command.new(command.to_s, [], cmd_opts)
        end
        if host.is_a? Array
          host.map { |h| on h, command, opts, &block }
        else
          @result = host.exec(command, opts)

          # Also, let additional checking be performed by the caller.
          yield self if block_given?

          return @result
        end
      end

      # @deprecated
      # An proxy for the last {Beaker::Result#stdout} returned by
      # a method that makes remote calls.  Use the {Beaker::Result}
      # object returned by the method directly instead. For Usage see
      # {Beaker::Result}.
      def stdout
        return nil if @result.nil?
        @result.stdout
      end

      # @deprecated
      # An proxy for the last {Beaker::Result#stderr} returned by
      # a method that makes remote calls.  Use the {Beaker::Result}
      # object returned by the method directly instead. For Usage see
      # {Beaker::Result}.
      def stderr
        return nil if @result.nil?
        @result.stderr
      end

      # @deprecated
      # An proxy for the last {Beaker::Result#exit_code} returned by
      # a method that makes remote calls.  Use the {Beaker::Result}
      # object returned by the method directly instead. For Usage see
      # {Beaker::Result}.
      def exit_code
        return nil if @result.nil?
        @result.exit_code
      end

      # Move a file from a remote to a local path
      # @note If using {Beaker::Host} for the hosts *scp* is not
      #   required on the system as it uses Ruby's net/scp library.  The
      #   net-scp gem however is required (and specified in the gemspec).
      #
      # @param [Host, #do_scp_from] host One or more hosts (or some object
      #                                  that responds like
      #                                  {Beaker::Host#do_scp_from}.
      # @param [String] from_path A remote path to a file.
      # @param [String] to_path   A local path to copy *from_path* to.
      # @!macro common_opts
      #
      # @return [Result] Returns the result of the SCP operation
      def scp_from host, from_path, to_path, opts = {}
        if host.is_a? Array
          host.each { |h| scp_from h, from_path, to_path, opts }
        else
          @result = host.do_scp_from(from_path, to_path, opts)
          @result.log logger
        end
      end

      # Move a local file to a remote host
      # @note If using {Beaker::Host} for the hosts *scp* is not
      #   required on the system as it uses Ruby's net/scp library.  The
      #   net-scp gem however is required (and specified in the gemspec.
      #
      # @param [Host, #do_scp_to] host One or more hosts (or some object
      #                                that responds like
      #                                {Beaker::Host#do_scp_to}.
      # @param [String] from_path A local path to a file.
      # @param [String] to_path   A remote path to copy *from_path* to.
      # @!macro common_opts
      #
      # @return [Result] Returns the result of the SCP operation
      def scp_to host, from_path, to_path, opts = {}
        if host.is_a? Array
          host.each { |h| scp_to h, from_path, to_path, opts }
        else
          @result = host.do_scp_to(from_path, to_path, opts)
          @result.log logger
        end
      end

      # Check to see if a package is installed on a remote host
      #
      # @param [Host] host             A host object
      # @param [String] package_name   Name of the package to check for.
      #
      # @return [Boolean] true/false if the package is found
      def check_for_package host, package_name
        host.check_for_package package_name
      end

      # Install a package on a host
      #
      # @param [Host] host             A host object
      # @param [String] package_name   Name of the package to install
      #
      # @return [Result]   An object representing the outcome of *install command*.
      def install_package host, package_name
        host.install_package package_name
      end

      # Create a remote file out of a string
      # @note This method uses Tempfile in Ruby's STDLIB as well as {#scp_to}.
      #
      # @param [Host, #do_scp_to] hosts One or more hosts (or some object
      #                                 that responds like
      #                                 {Beaker::Host#do_scp_from}.
      # @param [String] file_path A remote path to place *file_content* at.
      # @param [String] file_content The contents of the file to be placed.
      # @!macro common_opts
      #
      # @return [Result] Returns the result of the underlying SCP operation.
      def create_remote_file(hosts, file_path, file_content, opts = {})
        Tempfile.open 'beaker' do |tempfile|
          File.open(tempfile.path, 'w') {|file| file.puts file_content }

          scp_to hosts, tempfile.path, file_path, opts
        end
      end

      # Move a local script to a remote host and execute it
      # @note this relies on {#on} and {#scp_to}
      #
      # @param [Host, #do_scp_to] host One or more hosts (or some object
      #                                that responds like
      #                                {Beaker::Host#do_scp_from}.
      # @param [String] script A local path to find an executable script at.
      # @!macro common_opts
      # @param [Proc] block Additional tests to run after script has executed
      #
      # @return [Result] Returns the result of the underlying SCP operation.
      def run_script_on(host, script, opts = {}, &block)
        # this is unsafe as it uses the File::SEPARATOR will be set to that
        # of the coordinator node.  This works for us because we use cygwin
        # which will properly convert the paths.  Otherwise this would not
        # work for running tests on a windows machine when the coordinator
        # that the harness is running on is *nix. We should use
        # {Beaker::Host#temp_path} instead. TODO
        remote_path = File.join("", "tmp", File.basename(script))

        scp_to host, script, remote_path
        on host, remote_path, opts, &block
      end

      # Limit the hosts a test case is run against
      # @note This will modify the {Beaker::TestCase#hosts} member
      #   in place unless an array of hosts is passed into it and
      #   {Beaker::TestCase#logger} yielding an object that responds
      #   like {Beaker::Logger#warn}, as well as
      #   {Beaker::DSL::Outcomes#skip_test}, and optionally
      #   {Beaker::TestCase#hosts}.
      #
      # @param [Symbol] type The type of confinement to do. Valid parameters
      #                      are *:to* to confine the hosts to only those that
      #                      match *criteria* or *:except* to confine the test
      #                      case to only those hosts that do not match
      #                      criteria.
      # @param [Hash{Symbol,String=>String,Regexp,Array<String,Regexp>}]
      #   criteria Specify the criteria with which a host should be
      #   considered for inclusion or exclusion.  The key is any attribute
      #   of the host that will be yielded by {Beaker::Host#[]}.
      #   The value can be any string/regex or array of strings/regexp.
      #   The values are compared using {Enumerable#any?} so that if one
      #   value of an array matches the host is considered a match for that
      #   criteria.
      # @param [Array<Host>] host_array This creatively named parameter is
      #   an optional array of hosts to confine to.  If not passed in, this
      #   method will modify {Beaker::TestCase#hosts} in place.
      # @param [Proc] block Addition checks to determine suitability of hosts
      #   for confinement.  Each host that is still valid after checking
      #   *criteria* is then passed in turn into this block.  The block
      #   should return true if the host matches this additional criteria.
      #
      # @example Basic usage to confine to debian OSes.
      #     confine :to, :platform => 'debian'
      #
      # @example Confining to anything but Windows and Solaris
      #     confine :except, :platform => ['windows', 'solaris']
      #
      # @example Using additional block to confine to Solaris global zone.
      #     confine :to, :platform => 'solaris' do |solaris|
      #       on( solaris, 'zonename' ) =~ /global/
      #     end
      #
      # @return [Array<Host>] Returns an array of hosts that are still valid
      #   targets for this tests case.
      # @raise [SkipTest] Raises skip test if there are no valid hosts for
      #   this test case after confinement.
      def confine(type, criteria, host_array = nil, &block)
        provided_hosts = host_array ? true : false
        hosts_to_modify = host_array || hosts
        criteria.each_pair do |property, value|
          case type
          when :except
            hosts_to_modify = hosts_to_modify.reject do |host|
              inspect_host host, property, value
            end
            if block_given?
              hosts_to_modify = hosts_to_modify.reject do |host|
                yield host
              end
            end
          when :to
            hosts_to_modify = hosts_to_modify.select do |host|
              inspect_host host, property, value
            end
            if block_given?
              hosts_to_modify = hosts_to_modify.select do |host|
                yield host
              end
            end
          else
            raise "Unknown option #{type}"
          end
        end
        if hosts_to_modify.empty?
          logger.warn "No suitable hosts with: #{criteria.inspect}"
          skip_test 'No suitable hosts found'
        end
        self.hosts = hosts_to_modify
        hosts_to_modify
      end

      # Ensures that host restrictions as specifid by type, criteria and
      # host_array are confined to activity within the passed block.
      # TestCase#hosts is reset after block has executed.
      #
      # @see confine
      def confine_block(type, criteria, host_array = nil, &block)
        begin
          original_hosts = self.hosts.dup
          confine(type, criteria, host_array)

          yield

        ensure
          self.hosts = original_hosts
        end
      end

      # @!visibility private
      def inspect_host(host, property, one_or_more_values)
        values = Array(one_or_more_values)
        return values.any? do |value|
          true_false = false
          case value
          when String
            true_false = host[property.to_s].include? value
          when Regexp
            true_false = host[property.to_s] =~ value
          end
          true_false
        end
      end


      # Test Puppet running in a certain run mode with specific options.
      # This ensures the following steps are performed:
      # 1. The pre-test Puppet configuration is backed up
      # 2. A new Puppet configuraton file is layed down
      # 3. Puppet is started or restarted in the specified run mode
      # 4. Ensure Puppet has started correctly
      # 5. Further tests are yielded to
      # 6. Revert Puppet to the pre-test state
      # 7. Testing artifacts are saved in a folder named for the test
      #
      # @param [Host] host        One object that act like Host
      #
      # @param [Hash{Symbol=>String}] conf_opts  Represents puppet settings.
      #                            Sections of the puppet.conf may be
      #                            specified, if no section is specified the
      #                            a puppet.conf file will be written with the
      #                            options put in a section named after [mode]
      #
      #                            There is a special setting for command_line
      #                            arguments such as --debug or --logdest, which
      #                            cannot be set in puppet.conf.   For example:
      #
      #                            :__commandline_args__ => '--logdest /tmp/a.log'
      #
      #                            These will only be applied when starting a FOSS
      #                            master, as a pe master is just bounced.
      #
      # @param [File] testdir      The temporary directory which will hold backup
      #                            configuration, and other test artifacts.
      #
      # @param [Block]             block The point of this method, yields so
      #                            tests may be ran. After the block is finished
      #                            puppet will revert to a previous state.
      #
      # @example A simple use case to ensure a master is running
      #     with_puppet_running_on( master ) do
      #         ...tests that require a master...
      #     end
      #
      # @example Fully utilizing the possiblities of config options
      #     with_puppet_running_on( master,
      #                             :main => {:logdest => '/var/blah'},
      #                             :master => {:masterlog => '/elswhere'},
      #                             :agent => {:server => 'localhost'} ) do
      #
      #       ...tests to be ran...
      #     end
      #
      # @api dsl
      def with_puppet_running_on host, conf_opts, testdir = host.tmpdir(File.basename(@path)), &block
        raise(ArgumentError, "with_puppet_running_on's conf_opts must be a Hash. You provided a #{conf_opts.class}: '#{conf_opts}'") if !conf_opts.kind_of?(Hash)
        cmdline_args = conf_opts.delete(:__commandline_args__)

        begin
          backup_file = backup_the_file(host, host['puppetpath'], testdir, 'puppet.conf')
          lay_down_new_puppet_conf host, conf_opts, testdir

          if host.is_pe?
            bounce_service( host, 'pe-httpd' )
          else
            puppet_master_started = start_puppet_from_source_on!( host, cmdline_args )
          end

          yield self if block_given?

        rescue Exception => early_exception
          original_exception = RuntimeError.new("PuppetAcceptance::DSL::Helpers.with_puppet_running_on failed (check backtrace for location) because: #{early_exception}\n#{early_exception.backtrace.join("\n")}\n")
          raise(original_exception)

        ensure
          begin
            restore_puppet_conf_from_backup( host, backup_file )

            if host.is_pe?
              bounce_service( host, 'pe-httpd' )
            else
              stop_puppet_from_source_on( host ) if puppet_master_started
            end

          rescue Exception => teardown_exception
            if original_exception
              logger.error("Raised during attempt to teardown with_puppet_running_on: #{teardown_exception}\n---\n")
              raise original_exception
            else
              raise teardown_exception
            end
          end
        end
      end

      # @!visibility private
      def restore_puppet_conf_from_backup( host, backup_file )
        puppetpath = host['puppetpath']

        host.exec( Command.new( "if [ -f #{backup_file} ]; then " +
                                    "cat #{backup_file} > " +
                                    "#{puppetpath}/puppet.conf; " +
                                    "rm -f #{backup_file}; " +
                                "fi" ) )
      end

      # @!visibility private
      def backup_the_file host, current_dir, new_dir, filename = 'puppet.conf'
        old_location = current_dir + '/' + filename
        new_location = new_dir + '/' + filename + '.bak'

        host.exec( Command.new( "cp #{old_location} #{new_location}" ) )

        return new_location
      end

      # @!visibility private
      def start_puppet_from_source_on! host, args = ''
        host.exec( puppet( 'master', args ) )

        logger.debug 'Waiting for the puppet master to start'
        unless port_open_within?( host, 8140, 10 )
          dump_puppet_log(host)
          raise Beaker::DSL::FailTest, 'Puppet master did not start in a timely fashion'
        end
        logger.debug 'The puppet master has started'
        return true
      end

      # @!visibility private
      def stop_puppet_from_source_on( host )
        pid = host.exec( Command.new('cat `puppet master --configprint pidfile`') ).stdout.chomp
        host.exec( Command.new( "kill #{pid}" ) )
        Timeout.timeout(10) do
          while host.exec( Command.new( "kill -0 #{pid}"), :acceptable_exit_codes => [0,1] ).exit_code == 0 do
            # until kill -0 finds no process and we know that puppet has finished cleaning up
            sleep 1
          end
        end
      rescue RuntimeError => e
        dump_puppet_log host
        raise e
      end

      # @!visibility private
      def dump_puppet_log(host)
        syslogfile = case host['platform']
          when /fedora|centos|el/ then '/var/log/messages'
          when /ubuntu|debian/ then '/var/log/syslog'
          else return
        end

        logger.notify "\n*************************"
        logger.notify "* Dumping master log    *"
        logger.notify "*************************"
        host.exec( Command.new( "tail -n 100 #{syslogfile}" ), :acceptable_exit_codes => [0,1])
        logger.notify "*************************\n"
      end

      # @!visibility private
      def lay_down_new_puppet_conf( host, configuration_options, testdir )
        new_conf = puppet_conf_for( host, configuration_options )
        create_remote_file host, "#{testdir}/puppet.conf", new_conf.to_s

        host.exec(
          Command.new( "cat #{testdir}/puppet.conf > #{host['puppetpath']}/puppet.conf" ),
          :silent => true
        )
        host.exec( Command.new( "cat #{host['puppetpath']}/puppet.conf" ) )
      end

      # @!visibility private
      def puppet_conf_for host, conf_opts
        puppetconf = host.exec( Command.new( "cat #{host['puppetpath']}/puppet.conf" ) ).stdout
        new_conf   = IniFile.new( puppetconf ).merge( conf_opts )

        new_conf
      end

      # @!visibility private
      def bounce_service host, service
        # Any reason to not
        # host.exec puppet_resource( 'service', service, 'ensure=stopped' )
        # host.exec puppet_resource( 'service', service, 'ensure=running' )
        host.exec( Command.new( "/etc/init.d/#{service} restart" ) )
      end

      # Blocks until the port is open on the host specified, returns false
      # on failure
      def port_open_within?( host, port = 8140, seconds = 120 )
        repeat_for( seconds ) do
          host.port_open?( port )
        end
      end

      # Runs 'puppet apply' on a remote host, piping manifest through stdin
      #
      # @param [Host] host The host that this command should be run on
      #
      # @param [String] manifest The puppet manifest to apply
      #
      # @!macro common_opts
      # @option opts [Boolean]  :parseonly (false) If this key is true, the
      #                          "--parseonly" command line parameter will
      #                          be passed to the 'puppet apply' command.
      #
      # @option opts [Boolean]  :trace (false) If this key exists in the Hash,
      #                         the "--trace" command line parameter will be
      #                         passed to the 'puppet apply' command.
      #
      # @option opts [Boolean]  :catch_failures (false) By default
      #                         "puppet --apply" will exit with 0,
      #                         which does not count as a test
      #                         failure, even if there were errors applying
      #                         the manifest. This option enables detailed
      #                         exit codes and causes a test failure if
      #                         "puppet --apply" indicates there was a
      #                         failure during its execution.
      #
      # @param [Block] block This method will yield to a block of code passed
      #                      by the caller; this can be used for additional
      #                      validation, etc.
      #
      def apply_manifest_on(host, manifest, opts = {}, &block)
        on_options = {:stdin => manifest + "\n"}
        on_options[:acceptable_exit_codes] = opts.delete(:acceptable_exit_codes)
        args = ["--verbose"]
        args << "--parseonly" if opts[:parseonly]
        args << "--trace" if opts[:trace]

        if opts[:catch_failures]
          args << '--detailed-exitcodes'

          # From puppet help:
          # "... an exit code of '2' means there were changes, an exit code of
          # '4' means there were failures during the transaction, and an exit
          # code of '6' means there were both changes and failures."
          # We're after failures specifically so catch exit codes 4 and 6 only.
          on_options[:acceptable_exit_codes] |= [0, 2]
        end

        # Not really thrilled with this implementation, might want to improve it
        # later.  Basically, there is a magic trick in the constructor of
        # PuppetCommand which allows you to pass in a Hash for the last value in
        # the *args Array; if you do so, it will be treated specially.  So, here
        # we check to see if our caller passed us a hash of environment variables
        # that they want to set for the puppet command.  If so, we set the final
        # value of *args to a new hash with just one entry (the value of which
        # is our environment variables hash)
        if opts.has_key?(:environment)
          args << { :environment => opts[:environment]}
        end

        on host, puppet( 'apply', *args), on_options, &block
      end

      # @deprecated
      def run_agent_on(host, arg='--no-daemonize --verbose --onetime --test',
                       options={}, &block)
        if host.is_a? Array
          host.each { |h| run_agent_on h, arg, options, &block }
        else
          on host, puppet_agent(arg), options, &block
        end
      end

      # FIX: this should be moved into host/platform
      # @visibility private
      def run_cron_on(host, action, user, entry="", &block)
        platform = host['platform']
        if platform.include?('solaris') || platform.include?('aix') then
          case action
            when :list   then args = '-l'
            when :remove then args = '-r'
            when :add
              on( host,
                 "echo '#{entry}' > /var/spool/cron/crontabs/#{user}",
                  &block )
          end

        else # default for GNU/Linux platforms
          case action
            when :list   then args = '-l -u'
            when :remove then args = '-r -u'
            when :add
               on( host,
                  "echo '#{entry}' > /tmp/#{user}.cron && " +
                  "crontab -u #{user} /tmp/#{user}.cron",
                   &block )
          end
        end

        if args
          case action
            when :list, :remove then on(host, "crontab #{args} #{user}", &block)
          end
        end
      end

      # This method accepts a block and using the puppet resource 'host' will
      # setup host aliases before and after that block.
      #
      # A teardown step is also added to make sure unstubbing of the host is
      # removed always.
      #
      # @param machine [String] the host to execute this stub
      # @param ip_spec [Hash{String=>String}] a hash containing the host to ip
      #   mappings
      # @example Stub puppetlabs.com on the master to 127.0.0.1
      #   stub_hosts_on(master, 'puppetlabs.com' => '127.0.0.1')
      def stub_hosts_on(machine, ip_spec)
        ip_spec.each do |host, ip|
          logger.notify("Stubbing host #{host} to IP #{ip} on machine #{machine}")
          on( machine,
              puppet('resource', 'host', host, 'ensure=present', "ip=#{ip}") )
        end

        teardown do
          ip_spec.each do |host, ip|
            logger.notify("Unstubbing host #{host} to IP #{ip} on machine #{machine}")
            on( machine,
                puppet('resource', 'host', host, 'ensure=absent') )
          end
        end
      end

      # This wraps the method `stub_hosts_on` and makes the stub specific to
      # the forge alias.
      #
      # @param machine [String] the host to perform the stub on
      def stub_forge_on(machine)
        @forge_ip ||= Resolv.getaddress(forge)
        stub_hosts_on(machine, 'forge.puppetlabs.com' => @forge_ip)
      end
       def sleep_until_puppetdb_started(host)
         curl_with_retries("start puppetdb", host, "http://localhost:8080", 0, 120)
         curl_with_retries("start puppetdb (ssl)",
                           host, "https://#{host.node_name}:8081", [35, 60])
       end
 
       def curl_with_retries(desc, host, url, desired_exit_codes, max_retries = 60, retry_interval = 1)
         retry_command(desc, host, "curl #{url}", desired_exit_codes, max_retries, retry_interval)
       end
 
       def retry_command(desc, host, command, desired_exit_codes = 0, max_retries = 60, retry_interval = 1)
         desired_exit_codes = [desired_exit_codes].flatten
         result = on host, command, :acceptable_exit_codes => (0...127)
         num_retries = 0
         until desired_exit_codes.include?(result.exit_code)
           sleep retry_interval
           result = on host, command, :acceptable_exit_codes => (0...127)
           num_retries += 1
           if (num_retries > max_retries)
             fail("Unable to #{desc}")
           end
         end
       end
 
       #stops the puppet agent running on the host
       def stop_agent(agent)
         vardir = agent.puppet['vardir']
         agent_running = true
         while agent_running
           result = on agent, "[ -e '#{vardir}/state/agent_catalog_run.lock' ]", :acceptable_exit_codes => [0,1]
           agent_running = (result.exit_code == 0)
           sleep 2 unless agent_running
         end
        
         if agent['platform'].include?('solaris')
           on(agent, '/usr/sbin/svcadm disable -s svc:/network/pe-puppet:default')
         elsif agent['platform'].include?('aix')
           on(agent, '/usr/bin/stopsrc -s pe-puppet')
         elsif agent['platform'].include?('windows')
           on(agent, 'net stop pe-puppet', :acceptable_exit_codes => [0,2])
         else
           # For the sake of not passing the PE version into this method,
           # we just query the system to find out which service we want to
           # stop
           result = on agent, "[ -e /etc/init.d/pe-puppet-agent ]", :acceptable_exit_codes => [0,1]
           service = (result.exit_code == 0) ? 'pe-puppet-agent' : 'pe-puppet'
           on(agent, "/etc/init.d/#{service} stop")
         end
       end
 
 
       #wait for a given host to appear in the dashboard
       def wait_for_host_in_dashboard(host)
         hostname = host.node_name
         retry_command("Wait for #{hostname} to be in the console", dashboard, "! curl --sslv3 -k -I https://#{dashboard}/nodes/#{hostname} | grep '404 Not Found'")
       end
 
 
       #prompt the master to sign certs then check to confirm the cert for this host is signed
       def sign_certificate(host)
         return if [master, dashboard, database].include? host
 
         hostname = Regexp.escape host.node_name
 
         last_sleep = 0
         next_sleep = 1
         (0..10).each do |i|
           fail_test("Failed to sign cert for #{hostname}") if i == 10
 
           on master, puppet("cert --sign --all"), :acceptable_exit_codes => [0,24]
           break if on(master, puppet("cert --list --all")).stdout =~ /\+ "?#{hostname}"?/
           sleep next_sleep
           (last_sleep, next_sleep) = next_sleep, last_sleep+next_sleep
         end
       end
    end
  end
end
