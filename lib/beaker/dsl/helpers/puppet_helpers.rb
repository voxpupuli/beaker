require 'timeout'
require 'inifile'
require 'resolv'

module Beaker
  module DSL
    module Helpers
      # Methods that help you interact with your puppet installation, puppet must be installed
      # for these methods to execute correctly
      module PuppetHelpers

        # @!macro [new] common_opts
        #   @param [Hash{Symbol=>String}] opts Options to alter execution.
        #   @option opts [Boolean] :silent (false) Do not produce log output
        #   @option opts [Array<Fixnum>] :acceptable_exit_codes ([0]) An array
        #     (or range) of integer exit codes that should be considered
        #     acceptable.  An error will be thrown if the exit code does not
        #     match one of the values in this list.
        #   @option opts [Boolean] :accept_all_exit_codes (false) Consider all 
        #     exit codes as passing.
        #   @option opts [Boolean] :dry_run (false) Do not actually execute any
        #     commands on the SUT
        #   @option opts [String] :stdin (nil) Input to be provided during command
        #     execution on the SUT.
        #   @option opts [Boolean] :pty (false) Execute this command in a pseudoterminal.
        #   @option opts [Boolean] :expect_connection_failure (false) Expect this command
        #     to result in a connection failure, reconnect and continue execution.
        #   @option opts [Hash{String=>String}] :environment ({}) These will be
        #     treated as extra environment variables that should be set before
        #     running the command.
        #

        # Return the name of the puppet user.
        #
        # @param [Host] host One object that acts like a Beaker::Host
        #
        # @note This method assumes puppet is installed on the host.
        #
        def puppet_user(host)
          return host.puppet('master')['user']
        end

        # Return the name of the puppet group.
        #
        # @param [Host] host One object that acts like a Beaker::Host
        #
        # @note This method assumes puppet is installed on the host.
        #
        def puppet_group(host)
          return host.puppet('master')['group']
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
        # @note Whether Puppet is started or restarted depends on what kind of
        #   server you're running.  Passenger and puppetserver are restarted before.
        #   Webrick is started before and stopped after yielding, unless you're using
        #   service scripts, then it'll behave like passenger & puppetserver.
        #   Passenger and puppetserver (or webrick using service scripts)
        #   restart after yielding by default.  You can stop this from happening
        #   by setting the :restart_when_done flag of the conf_opts argument.
        #
        # @param [Host] host        One object that act like Host
        #
        # @param [Hash{Symbol=>String}] conf_opts  Represents puppet settings.
        #                            Sections of the puppet.conf may be
        #                            specified, if no section is specified the
        #                            a puppet.conf file will be written with the
        #                            options put in a section named after [mode]
        # @option conf_opts [String] :__commandline_args__  A special setting for
        #                            command_line arguments such as --debug or
        #                            --logdest, which cannot be set in
        #                            puppet.conf. For example:
        #
        #                            :__commandline_args__ => '--logdest /tmp/a.log'
        #
        #                            These will only be applied when starting a FOSS
        #                            master, as a pe master is just bounced.
        # @option conf_opts [Hash]   :__service_args__  A special setting of options
        #                            for controlling how the puppet master service is
        #                            handled. The only setting currently is
        #                            :bypass_service_script, which if set true will
        #                            force stopping and starting a webrick master
        #                            using the start_puppet_from_source_* methods,
        #                            even if it seems the host has passenger.
        #                            This is needed in FOSS tests to initialize
        #                            SSL.
        # @option conf_opts [Boolean] :restart_when_done  determines whether a restart
        #                            should be run after the test has been yielded to.
        #                            Will stop puppet if false. Default behavior
        #                            is to restart, but you can override this on the
        #                            host or with this option.
        #                            (Note: only works for passenger & puppetserver
        #                            masters (or webrick using the service scripts))
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
        def with_puppet_running_on host, conf_opts, testdir = host.tmpdir(File.basename(@path)), &block
          raise(ArgumentError, "with_puppet_running_on's conf_opts must be a Hash. You provided a #{conf_opts.class}: '#{conf_opts}'") if !conf_opts.kind_of?(Hash)
          cmdline_args = conf_opts[:__commandline_args__]
          service_args = conf_opts[:__service_args__] || {}
          restart_when_done = true
          restart_when_done = host[:restart_when_done] if host.has_key?(:restart_when_done)
          restart_when_done = conf_opts.fetch(:restart_when_done, restart_when_done)
          conf_opts = conf_opts.reject { |k,v| [:__commandline_args__, :__service_args__, :restart_when_done].include?(k) }

          curl_retries = host['master-start-curl-retries'] || options['master-start-curl-retries']
          logger.debug "Setting curl retries to #{curl_retries}"

          if options[:is_puppetserver]
            confdir = host.puppet('master')['confdir']
            vardir = host.puppet('master')['vardir']

            if cmdline_args
              split_args = cmdline_args.split()

              split_args.each do |arg|
                case arg
                when /--confdir=(.*)/
                  confdir = $1
                when /--vardir=(.*)/
                  vardir = $1
                end
              end
            end

            puppetserver_opts = { "jruby-puppet" => {
              "master-conf-dir" => confdir,
              "master-var-dir" => vardir,
            }}

            puppetserver_conf = File.join("#{host['puppetserver-confdir']}", "puppetserver.conf")
            modify_tk_config(host, puppetserver_conf, puppetserver_opts)
          end
          begin
            backup_file = backup_the_file(host, host.puppet('master')['confdir'], testdir, 'puppet.conf')
            lay_down_new_puppet_conf host, conf_opts, testdir

            if host.use_service_scripts? && !service_args[:bypass_service_script]
              bounce_service( host, host['puppetservice'], curl_retries )
            else
              puppet_master_started = start_puppet_from_source_on!( host, cmdline_args )
            end

            yield self if block_given?

          rescue Beaker::DSL::Assertions, Minitest::Assertion => early_assertion
            fail_test(early_assertion)
          rescue Exception => early_exception
            original_exception = RuntimeError.new("PuppetAcceptance::DSL::Helpers.with_puppet_running_on failed (check backtrace for location) because: #{early_exception}\n#{early_exception.backtrace.join("\n")}\n")
            raise(original_exception)

          ensure
            begin

              if host.use_service_scripts? && !service_args[:bypass_service_script]
                restore_puppet_conf_from_backup( host, backup_file )
                if restart_when_done
                  bounce_service( host, host['puppetservice'], curl_retries )
                else
                  host.exec puppet_resource('service', host['puppetservice'], 'ensure=stopped')
                end
              else
                if puppet_master_started
                  stop_puppet_from_source_on( host )
                else
                  dump_puppet_log(host)
                end
                restore_puppet_conf_from_backup( host, backup_file )
              end

            rescue Exception => teardown_exception
              begin
                if !host.is_pe?
                  dump_puppet_log(host)
                end
              rescue Exception => dumping_exception
                logger.error("Raised during attempt to dump puppet logs: #{dumping_exception}")
              end

              if original_exception
                logger.error("Raised during attempt to teardown with_puppet_running_on: #{teardown_exception}\n---\n")
                raise original_exception
              else
                raise teardown_exception
              end
            end
          end
        end

        # Test Puppet running in a certain run mode with specific options,
        # on the default host
        # @see #with_puppet_running_on
        def with_puppet_running conf_opts, testdir = host.tmpdir(File.basename(@path)), &block
          with_puppet_running_on(default, conf_opts, testdir, &block)
        end

        # @!visibility private
        def restore_puppet_conf_from_backup( host, backup_file )
          puppet_conf = host.puppet('master')['config']

          if backup_file
            host.exec( Command.new( "if [ -f '#{backup_file}' ]; then " +
                                        "cat '#{backup_file}' > " +
                                        "'#{puppet_conf}'; " +
                                        "rm -f '#{backup_file}'; " +
                                    "fi" ) )
          else
            host.exec( Command.new( "rm -f '#{puppet_conf}'" ))
          end

        end

        # @!visibility private
        def start_puppet_from_source_on! host, args = ''
          host.exec( puppet( 'master', args ) )

          logger.debug 'Waiting for the puppet master to start'
          unless port_open_within?( host, 8140, 10 )
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
        end

        # @!visibility private
        def dump_puppet_log(host)
          syslogfile = case host['platform']
            when /fedora|centos|el|redhat|scientific/ then '/var/log/messages'
            when /ubuntu|debian|cumulus/ then '/var/log/syslog'
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
          puppetconf_main = host.puppet('master')['config']
          puppetconf_filename = File.basename(puppetconf_main)
          puppetconf_test = File.join(testdir, puppetconf_filename)

          new_conf = puppet_conf_for( host, configuration_options )
          create_remote_file host, puppetconf_test, new_conf.to_s

          host.exec(
            Command.new( "cat #{puppetconf_test} > #{puppetconf_main}" ),
            :silent => true
          )
          host.exec( Command.new( "cat #{puppetconf_main}" ) )
        end

        # @!visibility private
        def puppet_conf_for host, conf_opts
          puppetconf = host.exec( Command.new( "cat #{host.puppet('master')['config']}" ) ).stdout
          new_conf   = IniFile.new( puppetconf ).merge( conf_opts )

          new_conf
        end

        # @!visibility private
        def bounce_service host, service, curl_retries = 120
          if host.graceful_restarts?
            apachectl_path = host.is_pe? ? "#{host['puppetsbindir']}/apache2ctl" : 'apache2ctl'
            host.exec(Command.new("#{apachectl_path} graceful"))
          else
            host.exec puppet_resource('service', service, 'ensure=stopped')
            host.exec puppet_resource('service', service, 'ensure=running')
          end
          curl_with_retries(" #{service} ", host, "https://localhost:8140", [35, 60], curl_retries)
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
        # @option opts [Array<Integer>] :acceptable_exit_codes ([0]) The list of exit
        #                          codes that will NOT raise an error when found upon
        #                          command completion.  If provided, these values will
        #                          be combined with those used in :catch_failures and
        #                          :expect_failures to create the full list of
        #                          passing exit codes.
        #
        # @option opts [Hash]     :environment Additional environment variables to be
        #                         passed to the 'puppet apply' command
        #
        # @option opts [Boolean]  :catch_failures (false) By default `puppet
        #                         --apply` will exit with 0, which does not count
        #                         as a test failure, even if there were errors or
        #                         changes when applying the manifest. This option
        #                         enables detailed exit codes and causes a test
        #                         failure if `puppet --apply` indicates there was
        #                         a failure during its execution.
        #
        # @option opts [Boolean]  :catch_changes (false) This option enables
        #                         detailed exit codes and causes a test failure
        #                         if `puppet --apply` indicates that there were
        #                         changes or failures during its execution.
        #
        # @option opts [Boolean]  :expect_changes (false) This option enables
        #                         detailed exit codes and causes a test failure
        #                         if `puppet --apply` indicates that there were
        #                         no resource changes during its execution.
        #
        # @option opts [Boolean]  :expect_failures (false) This option enables
        #                         detailed exit codes and causes a test failure
        #                         if `puppet --apply` indicates there were no
        #                         failure during its execution.
        #
        # @option opts [Boolean]  :future_parser (false) This option enables
        #                         the future parser option that is available
        #                         from Puppet verion 3.2
        #                         By default it will use the 'current' parser.
        #
        # @option opts [Boolean]  :noop (false) If this option exists, the
        #                         the "--noop" command line parameter will be
        #                         passed to the 'puppet apply' command.
        #
        # @option opts [String]   :modulepath The search path for modules, as
        #                         a list of directories separated by the system
        #                         path separator character. (The POSIX path separator
        #                         is ‘:’, and the Windows path separator is ‘;’.)
        #
        # @option opts [String]   :debug (false) If this option exists,
        #                         the "--debug" command line parameter
        #                         will be passed to the 'puppet apply' command.
        #
        # @param [Block] block This method will yield to a block of code passed
        #                      by the caller; this can be used for additional
        #                      validation, etc.
        #
        # @return [Array<Result>, Result] An array of results, or a result object.
        #   Check {#run_block_on} for more details on this.
        def apply_manifest_on(host, manifest, opts = {}, &block)
          block_on host do | host |
            on_options = {}
            on_options[:acceptable_exit_codes] = Array(opts[:acceptable_exit_codes])

            puppet_apply_opts = {}
            if opts[:debug]
              puppet_apply_opts[:debug] = nil
            else
              puppet_apply_opts[:verbose] = nil
            end
            puppet_apply_opts[:parseonly] = nil if opts[:parseonly]
            puppet_apply_opts[:trace] = nil if opts[:trace]
            puppet_apply_opts[:parser] = 'future' if opts[:future_parser]
            puppet_apply_opts[:modulepath] = opts[:modulepath] if opts[:modulepath]
            puppet_apply_opts[:noop] = nil if opts[:noop]

            # From puppet help:
            # "... an exit code of '2' means there were changes, an exit code of
            # '4' means there were failures during the transaction, and an exit
            # code of '6' means there were both changes and failures."
            if [opts[:catch_changes],opts[:catch_failures],opts[:expect_failures],opts[:expect_changes]].compact.length > 1
              raise(ArgumentError,
                    'Cannot specify more than one of `catch_failures`, ' +
                    '`catch_changes`, `expect_failures`, or `expect_changes` ' +
                    'for a single manifest')
            end

            if opts[:catch_changes]
              puppet_apply_opts['detailed-exitcodes'] = nil

              # We're after idempotency so allow exit code 0 only.
              on_options[:acceptable_exit_codes] |= [0]
            elsif opts[:catch_failures]
              puppet_apply_opts['detailed-exitcodes'] = nil

              # We're after only complete success so allow exit codes 0 and 2 only.
              on_options[:acceptable_exit_codes] |= [0, 2]
            elsif opts[:expect_failures]
              puppet_apply_opts['detailed-exitcodes'] = nil

              # We're after failures specifically so allow exit codes 1, 4, and 6 only.
              on_options[:acceptable_exit_codes] |= [1, 4, 6]
            elsif opts[:expect_changes]
              puppet_apply_opts['detailed-exitcodes'] = nil

              # We're after changes specifically so allow exit code 2 only.
              on_options[:acceptable_exit_codes] |= [2]
            else
              # Either use the provided acceptable_exit_codes or default to [0]
              on_options[:acceptable_exit_codes] |= [0]
            end

            # Not really thrilled with this implementation, might want to improve it
            # later. Basically, there is a magic trick in the constructor of
            # PuppetCommand which allows you to pass in a Hash for the last value in
            # the *args Array; if you do so, it will be treated specially. So, here
            # we check to see if our caller passed us a hash of environment variables
            # that they want to set for the puppet command. If so, we set the final
            # value of *args to a new hash with just one entry (the value of which
            # is our environment variables hash)
            if opts.has_key?(:environment)
              puppet_apply_opts['ENV'] = opts[:environment]
            end

            file_path = host.tmpfile('apply_manifest.pp')
            create_remote_file(host, file_path, manifest + "\n")

            if host[:default_apply_opts].respond_to? :merge
              puppet_apply_opts = host[:default_apply_opts].merge( puppet_apply_opts )
            end

            on host, puppet('apply', file_path, puppet_apply_opts), on_options, &block
          end
        end

        # Runs 'puppet apply' on default host, piping manifest through stdin
        # @see #apply_manifest_on
        def apply_manifest(manifest, opts = {}, &block)
          apply_manifest_on(default, manifest, opts, &block)
        end

        # @deprecated
        def run_agent_on(host, arg='--no-daemonize --verbose --onetime --test',
                         options={}, &block)
          block_on host do | host |
            on host, puppet_agent(arg), options, &block
          end
        end

        # This method using the puppet resource 'host' will setup host aliases
        # and register the remove of host aliases via Beaker::TestCase#teardown
        #
        # A teardown step is also added to make sure unstubbing of the host is
        # removed always.
        #
        # @param [Host, Array<Host>, String, Symbol] machine    One or more hosts to act upon,
        #                            or a role (String or Symbol) that identifies one or more hosts.
        # @param ip_spec [Hash{String=>String}] a hash containing the host to ip
        #   mappings
        # @example Stub puppetlabs.com on the master to 127.0.0.1
        #   stub_hosts_on(master, 'puppetlabs.com' => '127.0.0.1')
        def stub_hosts_on(machine, ip_spec)
          block_on machine do | host |
            ip_spec.each do |address, ip|
              logger.notify("Stubbing address #{address} to IP #{ip} on machine #{host}")
              on( host, puppet('resource', 'host', address, 'ensure=present', "ip=#{ip}") )
            end

            teardown do
              ip_spec.each do |address, ip|
                logger.notify("Unstubbing address #{address} to IP #{ip} on machine #{host}")
                on( host, puppet('resource', 'host', address, 'ensure=absent') )
              end
            end
          end
        end

        # This method accepts a block and using the puppet resource 'host' will
        # setup host aliases before and after that block.
        #
        # @param [Host, Array<Host>, String, Symbol] host    One or more hosts to act upon,
        #                            or a role (String or Symbol) that identifies one or more hosts.
        # @param ip_spec [Hash{String=>String}] a hash containing the host to ip
        #   mappings
        # @example Stub puppetlabs.com on the master to 127.0.0.1
        #   with_host_stubbed_on(master, 'forgeapi.puppetlabs.com' => '127.0.0.1') do
        #     puppet( "module install puppetlabs-stdlib" )
        #   end
        def with_host_stubbed_on(host, ip_spec, &block)
          begin
            block_on host do |host|
              ip_spec.each_pair do |address, ip|
                logger.notify("Stubbing address #{address} to IP #{ip} on machine #{host}")
                on( host, puppet('resource', 'host', address, 'ensure=present', "ip=#{ip}") )
              end
            end

            block.call

          ensure
            ip_spec.each do |address, ip|
              logger.notify("Unstubbing address #{address} to IP #{ip} on machine #{host}")
              on( host, puppet('resource', 'host', address, 'ensure=absent') )
            end
          end
        end

        # This method accepts a block and using the puppet resource 'host' will
        # setup host aliases before and after that block on the default host
        #
        # @example Stub puppetlabs.com on the default host to 127.0.0.1
        #   stub_hosts('puppetlabs.com' => '127.0.0.1')
        # @see #stub_hosts_on
        def stub_hosts(ip_spec)
          stub_hosts_on(default, ip_spec)
        end

        # This wraps the method `stub_hosts_on` and makes the stub specific to
        # the forge alias.
        #
        # forge api v1 canonical source is forge.puppetlabs.com
        # forge api v3 canonical source is forgeapi.puppetlabs.com
        #
        # @param machine [String] the host to perform the stub on
        # @param forge_host [String] The URL to use as the forge alias, will default to using :forge_host in the
        #                             global options hash
        def stub_forge_on(machine, forge_host = nil)
          #use global options hash
          forge_host ||= options[:forge_host]
          @forge_ip ||= Resolv.getaddress(forge_host)
          block_on machine do | host |
            stub_hosts_on(host, 'forge.puppetlabs.com' => @forge_ip)
            stub_hosts_on(host, 'forgeapi.puppetlabs.com' => @forge_ip)
          end
        end

        # This wraps the method `with_host_stubbed_on` and makes the stub specific to
        # the forge alias.
        #
        # forge api v1 canonical source is forge.puppetlabs.com
        # forge api v3 canonical source is forgeapi.puppetlabs.com
        #
        # @param host [String] the host to perform the stub on
        # @param forge_host [String] The URL to use as the forge alias, will default to using :forge_host in the
        #                             global options hash
        def with_forge_stubbed_on( host, forge_host = nil, &block )
          #use global options hash
          forge_host ||= options[:forge_host]
          @forge_ip ||= Resolv.getaddress(forge_host)
          with_host_stubbed_on( host,
                                {'forge.puppetlabs.com'  => @forge_ip,
                               'forgeapi.puppetlabs.com' => @forge_ip},
                                &block                                    )
        end

        # This wraps `with_forge_stubbed_on` and provides it the default host
        # @see with_forge_stubbed_on
        def with_forge_stubbed( forge_host = nil, &block )
          with_forge_stubbed_on( default, forge_host, &block )
        end

        # This wraps the method `stub_hosts` and makes the stub specific to
        # the forge alias.
        #
        # @see #stub_forge_on
        def stub_forge(forge_host = nil)
          #use global options hash
          forge_host ||= options[:forge_host]
          stub_forge_on(default, forge_host)
        end

        def sleep_until_puppetdb_started(host)
          curl_with_retries("start puppetdb", host, "http://localhost:8080", 0, 120)
          curl_with_retries("start puppetdb (ssl)",
                            host, "https://#{host.node_name}:8081", [35, 60])
        end

        def sleep_until_puppetserver_started(host)
          curl_with_retries("start puppetserver (ssl)",
                            host, "https://#{host.node_name}:8140", [35, 60])
        end

        def sleep_until_nc_started(host)
          curl_with_retries("start nodeclassifier (ssl)",
                            host, "https://#{host.node_name}:4433", [35, 60])
        end
        #stops the puppet agent running on the host
        # @param [Host, Array<Host>, String, Symbol] agent    One or more hosts to act upon,
        #                            or a role (String or Symbol) that identifies one or more hosts.
        def stop_agent_on(agent)
          block_on agent do | host |
            vardir = agent.puppet['vardir']
            agent_running = true
            while agent_running
              agent_running = agent.file_exist?("#{vardir}/state/agent_catalog_run.lock")
              if agent_running
                sleep 2
              end
            end

            # In 4.0 this was changed to just be `puppet`
            agent_service = 'puppet'
            if !aio_version?(agent)
              # The agent service is `pe-puppet` everywhere EXCEPT certain linux distros on PE 2.8
              # In all the case that it is different, this init script will exist. So we can assume
              # that if the script doesn't exist, we should just use `pe-puppet`
              agent_service = 'pe-puppet-agent'
              agent_service = 'pe-puppet' unless agent.file_exist?('/etc/init.d/pe-puppet-agent')
            end

            # Under a number of stupid circumstances, we can't stop the
            # agent using puppet.  This is usually because of issues with
            # the init script or system on that particular configuration.
            avoid_puppet_at_all_costs = false
            avoid_puppet_at_all_costs ||= agent['platform'] =~ /el-4/
            avoid_puppet_at_all_costs ||= agent['pe_ver'] && version_is_less(agent['pe_ver'], '3.2') && agent['platform'] =~ /sles/

            if avoid_puppet_at_all_costs
              # When upgrading, puppet is already stopped. On EL4, this causes an exit code of '1'
              on agent, "/etc/init.d/#{agent_service} stop", :acceptable_exit_codes => [0, 1]
            else
              on agent, puppet_resource('service', agent_service, 'ensure=stopped')
            end
          end
        end

        #stops the puppet agent running on the default host
        # @see #stop_agent_on
        def stop_agent
          stop_agent_on(default)
        end

        #wait for a given host to appear in the dashboard
        def wait_for_host_in_dashboard(host)
          hostname = host.node_name
          if host['platform'] =~ /aix/ then
            curl_opts = '--tlsv1 -I'
          else
            curl_opts = '--tlsv1 -k -I'
          end
          retry_on(dashboard, "! curl #{curl_opts} https://#{dashboard}/nodes/#{hostname} | grep '404 Not Found'")
        end

        # Ensure the host has requested a cert, then sign it
        #
        # @param [Host, Array<Host>, String, Symbol] host    One or more hosts to act upon,
        #                            or a role (String or Symbol) that identifies one or more hosts.
        #
        # @return nil
        # @raise [FailTest] if process times out
        def sign_certificate_for(host)
          block_on host do | host |
            if [master, dashboard, database].include? host

              on host, puppet( 'agent -t' ), :acceptable_exit_codes => [0,1,2]
              on master, puppet( "cert --allow-dns-alt-names sign #{host}" ), :acceptable_exit_codes => [0,24]

            else

              hostname = Regexp.escape host.node_name

              last_sleep = 0
              next_sleep = 1
              (0..10).each do |i|
                fail_test("Failed to sign cert for #{hostname}") if i == 10

                on master, puppet("cert --sign --all --allow-dns-alt-names"), :acceptable_exit_codes => [0,24]
                break if on(master, puppet("cert --list --all")).stdout =~ /\+ "?#{hostname}"?/
                sleep next_sleep
                (last_sleep, next_sleep) = next_sleep, last_sleep+next_sleep
              end

            end
          end
        end

        #prompt the master to sign certs then check to confirm the cert for the default host is signed
        #@see #sign_certificate_for
        def sign_certificate
          sign_certificate_for(default)
        end

        # Create a temp directory on remote host with a user.  Default user
        # is puppet master user.
        #
        # @param [Host] host A single remote host on which to create and adjust
        # the ownership of a temp directory.
        # @param [String] name A remote path prefix for the new temp
        # directory. Default value is '/tmp/beaker'
        # @param [String] user The name of user that should own the temp
        # directory. If no username is specified, use `puppet master
        # --configprint user` to obtain username from master. Raise RuntimeError
        # if this puppet command returns a non-zero exit code.
        #
        # @return [String] Returns the name of the newly-created dir.
        def create_tmpdir_for_user(host, name='/tmp/beaker', user=nil)
          if not user
            result = on host, puppet("master --configprint user")
            if not result.exit_code == 0
              raise "`puppet master --configprint` failed, check that puppet is installed on #{host} or explicitly pass in a user name."
            end
            user = result.stdout.strip
          end

          create_tmpdir_on(host, name, user)

        end

      end
    end
  end
end
