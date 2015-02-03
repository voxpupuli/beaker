# -*- coding: utf-8 -*-
require 'resolv'
require 'inifile'
require 'timeout'
require 'beaker/dsl/outcomes'
require 'beaker/options'
require 'hocon'
require 'hocon/config_error'

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
    # * a method *options* that provides an options hash, see {Beaker::Options::OptionsHash}
    # * a method *logger* that yields a logger implementing
    #   {Beaker::Logger}'s interface.
    # * the module {Beaker::DSL::Roles} that provides access to the various hosts implementing
    #   {Beaker::Host}'s interface to act upon
    # * the module {Beaker::DSL::Wrappers} the provides convenience methods for {Beaker::DSL::Command} creation
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
      # @param [Host, Array<Host>, String, Symbol] host    One or more hosts to act upon,
      #                            or a role (String or Symbol) that identifies one or more hosts.
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
      # @example Using a role (defined in a String)  to identify the host
      #   on "master", "echo hello"
      #
      # @example Using a role (defined in a Symbol) to identify the host
      #   on :dashboard, "echo hello"
      #
      # @return [Result]   An object representing the outcome of *command*.
      # @raise  [FailTest] Raises an exception if *command* obviously fails.
      def on(host, command, opts = {}, &block)
        block_on host do | host |
          cur_command = command
          if command.is_a? Command
            cur_command = command.cmd_line(host)
          end
          cmd_opts = {}
          #add any additional environment variables to the command
          if opts[:environment]
            cmd_opts['ENV'] = opts[:environment]
          end
          @result = host.exec(Command.new(cur_command.to_s, [], cmd_opts), opts)

          # Also, let additional checking be performed by the caller.
          if block_given?
            case block.arity
              #block with arity of 0, just hand back yourself
              when 0
                yield self
              #block with arity of 1 or greater, hand back the result object
              else
                yield @result
            end
          end
          @result
        end
      end

      # The method for executing commands on the default host
      #
      # @param [String, Command]   command The command to execute on *host*.
      # @param [Proc]              block   Additional actions or assertions.
      # @!macro common_opts
      #
      # @example Most basic usage
      #     shell 'ls /tmp'
      #
      # @example Allowing additional exit codes to pass
      #     shell 'puppet agent -t', :acceptable_exit_codes => [0,2]
      #
      # @example Using the returned result for any kind of checking
      #     if shell('ls -la ~').stdout =~ /\.bin/
      #       ...do some action...
      #     end
      #
      # @example Using TestCase helpers from within a test.
      #     agents.each do |agent|
      #       shell('cat /etc/puppet/puppet.conf') do |result|
      #         assert_match result.stdout, /server = #{master}/, 'WTF Mate'
      #       end
      #     end
      #
      # @return [Result]   An object representing the outcome of *command*.
      # @raise  [FailTest] Raises an exception if *command* obviously fails.
      def shell(command, opts = {}, &block)
        on(default, command, opts, &block)
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
        block_on host do | host |
          @result = host.do_scp_from(from_path, to_path, opts)
          @result.log logger
          @result
        end
      end

      # Move a local file to a remote host
      # @note If using {Beaker::Host} for the hosts *scp* is not
      #   required on the system as it uses Ruby's net/scp library.  The
      #   net-scp gem however is required (and specified in the gemspec.
      #   When using SCP with Windows it will now auto expand path when
      #   using `cygpath instead of failing or requiring full path
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
        block_on host do | host |
          if host['platform'] =~ /windows/ && to_path.match('`cygpath')
            result = on host, "echo #{to_path}"
            to_path = result.raw_output.chomp
          end
          @result = host.do_scp_to(from_path, to_path, opts)
          @result.log logger
          @result
        end
      end

      # Deploy packaging configurations generated by
      # https://github.com/puppetlabs/packaging to a host.
      #
      # @note To ensure the repo configs are available for deployment,
      #       you should run `rake pl:jenkins:deb_repo_configs` and
      #       `rake pl:jenkins:rpm_repo_configs` on your project checkout
      #
      # @param [Host] host
      # @param [String] path     The path to the generated repository config
      #                          files. ex: /myproject/pkg/repo_configs
      # @param [String] name     A human-readable name for the repository
      # @param [String] version  The version of the project, as used by the
      #                          packaging tools. This can be determined with
      #                          `rake pl:print_build_params` from the packaging
      #                          repo.
      def deploy_package_repo host, path, name, version
        host.deploy_package_repo path, name, version
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

      # Create a temp directory on remote host owned by specified user.
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
      # @return [String] Returns the name of the newly-created file.
      def create_tmpdir_for_user(host, name='/tmp/beaker', user=nil)
        if not user
          result = on host, puppet("master --configprint user")
          if not result.exit_code == 0
            raise "`puppet master --configprint` failed, check that puppet is installed on #{host} or explicitly pass in a user name."
          end
          user = result.stdout.strip
        end

        if not on(host, "getent passwd #{user}").exit_code == 0
          raise "User #{user} does not exist on #{host}."
        end

        if defined? host.tmpdir
          dir = host.tmpdir(name)
          on host, "chown #{user}:#{user} #{dir}"
          return dir
        else
          raise "Host platform not supported by `create_tmpdir_for_user`."
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

      # Move a local script to default host and execute it
      # @see #run_script_on
      def run_script(script, opts = {}, &block)
        run_script_on(default, script, opts, &block)
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
      #   The values are compared using [Enumerable#any?] so that if one
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
        hosts_to_modify = host_array || hosts
        case type
        when :except
          hosts_to_modify = hosts_to_modify - select_hosts(criteria, hosts_to_modify, &block)
        when :to
          hosts_to_modify = select_hosts(criteria, hosts_to_modify, &block)
        else
          raise "Unknown option #{type}"
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
      # @see #confine
      def confine_block(type, criteria, host_array = nil, &block)
        begin
          original_hosts = self.hosts.dup
          confine(type, criteria, host_array)

          yield

        ensure
          self.hosts = original_hosts
        end
      end

      #Return a set of hosts that meet the given criteria
      # @param [Hash{Symbol,String=>String,Regexp,Array<String,Regexp>}]
      #   criteria Specify the criteria with which a host should be
      #   considered for inclusion.  The key is any attribute
      #   of the host that will be yielded by {Beaker::Host#[]}.
      #   The value can be any string/regex or array of strings/regexp.
      #   The values are compared using [Enumerable#any?] so that if one
      #   value of an array matches the host is considered a match for that
      #   criteria.
      # @param [Array<Host>] host_array This creatively named parameter is
      #   an optional array of hosts to confine to.  If not passed in, this
      #   method will modify {Beaker::TestCase#hosts} in place.
      # @param [Proc] block Addition checks to determine suitability of hosts
      #   for selection.  Each host that is still valid after checking
      #   *criteria* is then passed in turn into this block.  The block
      #   should return true if the host matches this additional criteria.
      #
      # @return [Array<Host>] Returns an array of hosts that meet the provided criteria
      def select_hosts(criteria, host_array = nil, &block)
        hosts_to_select_from = host_array || hosts
        criteria.each_pair do |property, value|
          hosts_to_select_from = hosts_to_select_from.select do |host|
            inspect_host host, property, value
          end
        end
        if block_given?
          hosts_to_select_from = hosts_to_select_from.select do |host|
            yield host
          end
        end
        hosts_to_select_from
      end

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
        cmdline_args = conf_opts[:__commandline_args__]
        service_args = conf_opts[:__service_args__] || {}
        conf_opts = conf_opts.reject { |k,v| [:__commandline_args__, :__service_args__].include?(k) }

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
          backup_file = backup_the_file(host, host['puppetconfdir'], testdir, 'puppet.conf')
          lay_down_new_puppet_conf host, conf_opts, testdir

          if host.use_service_scripts? && !service_args[:bypass_service_script]
            bounce_service( host, host['puppetservice'], curl_retries )
          else
            puppet_master_started = start_puppet_from_source_on!( host, cmdline_args )
          end

          yield self if block_given?

        rescue Exception => early_exception
          original_exception = RuntimeError.new("PuppetAcceptance::DSL::Helpers.with_puppet_running_on failed (check backtrace for location) because: #{early_exception}\n#{early_exception.backtrace.join("\n")}\n")
          raise(original_exception)

        ensure
          begin

            if host.use_service_scripts? && !service_args[:bypass_service_script]
              restore_puppet_conf_from_backup( host, backup_file )
              bounce_service( host, host['puppetservice'], curl_retries )
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
      # @api dsl
      # @see #with_puppet_running_on
      def with_puppet_running conf_opts, testdir = host.tmpdir(File.basename(@path)), &block
        with_puppet_running_on(default, conf_opts, testdir, &block)
      end

      # @!visibility private
      def restore_puppet_conf_from_backup( host, backup_file )
        puppetpath = host['puppetconfdir']
        puppet_conf = File.join(puppetpath, "puppet.conf")

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

      # Back up the given file in the current_dir to the new_dir
      #
      # @!visibility private
      #
      # @param host [Beaker::Host] The target host
      # @param current_dir [String] The directory containing the file to back up
      # @param new_dir [String] The directory to copy the file to
      # @param filename [String] The file to back up. Defaults to 'puppet.conf'
      #
      # @return [String, nil] The path to the file if the file exists, nil if it
      #   doesn't exist.
      def backup_the_file host, current_dir, new_dir, filename = 'puppet.conf'

        old_location = current_dir + '/' + filename
        new_location = new_dir + '/' + filename + '.bak'

        if host.file_exist? old_location
          host.exec( Command.new( "cp #{old_location} #{new_location}" ) )
          return new_location
        else
          logger.warn "Could not backup file '#{old_location}': no such file"
          nil
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
        puppetconf_test = "#{testdir}/puppet.conf"
        puppetconf_main = "#{host['puppetconfdir']}/puppet.conf"

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
        puppetconf = host.exec( Command.new( "cat #{host['puppetconfdir']}/puppet.conf" ) ).stdout
        new_conf   = IniFile.new( puppetconf ).merge( conf_opts )

        new_conf
      end

      # Modify the given TrapperKeeper config file.
      #
      # @param [Host] host  A host object
      # @param [OptionsHash] options_hash  New hash which will be merged into
      #                                    the given TrapperKeeper config.
      # @param [String] config_file_path  Path to the TrapperKeeper config on
      #                                   the given host which is to be
      #                                   modified.
      # @param [Bool] replace  If set true, instead of updating the existing
      #                        TrapperKeeper configuration, replace it entirely
      #                        with the contents of the given hash.
      #
      # @note TrapperKeeper config files can be HOCON, JSON, or Ini. We don't
      # particularly care which of these the file named by `config_file_path` on
      # the SUT actually is, just that the contents can be parsed into a map.
      #
      def modify_tk_config(host, config_file_path, options_hash, replace=false)
        if options_hash.empty?
          return nil
        end

        new_hash = Beaker::Options::OptionsHash.new

        if replace
          new_hash.merge!(options_hash)
        else
          if not host.file_exist?( config_file_path )
            raise "Error: #{config_file_path} does not exist on #{host}"
          end
          file_string = host.exec( Command.new( "cat #{config_file_path}" )).stdout

          begin
            tk_conf_hash = read_tk_config_string(file_string)
          rescue RuntimeError
            raise "Error reading trapperkeeper config: #{config_file_path} at host: #{host}"
          end

          new_hash.merge!(tk_conf_hash)
          new_hash.merge!(options_hash)
        end

        file_string = JSON.dump(new_hash)
        create_remote_file host, config_file_path, file_string
      end

      # The Trapperkeeper config service will accept HOCON (aka typesafe), JSON,
      # or Ini configuration files which means we need to safely handle the the
      # exceptions that might come from parsing the given string with the wrong
      # parser and fall back to the next valid parser in turn. We finally raise
      # a RuntimeException if none of the parsers succeed.
      #
      # @!visibility private
      def read_tk_config_string( string )
          begin
            return Hocon.parse(string)
          rescue Hocon::ConfigError
            nil
          end

          begin
            return JSON.parse(string)
          rescue JSON::JSONError
            nil
          end

          begin
            return IniFile.new(string)
          rescue IniFile::Error
            nil
          end

          raise "Failed to read TrapperKeeper config!"
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

      # FIX: this should be moved into host/platform
      # @visibility private
      def run_cron_on(host, action, user, entry="", &block)
        block_on host do | host |
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

      def curl_with_retries(desc, host, url, desired_exit_codes, max_retries = 60, retry_interval = 1)
        opts = {
          :desired_exit_codes => desired_exit_codes,
          :max_retries => max_retries,
          :retry_interval => retry_interval
        }
        retry_on(host, "curl -m 1 #{url}", opts)
      end

      # This command will execute repeatedly until success or it runs out with an error
      #
      # @param [Host, Array<Host>, String, Symbol] host    One or more hosts to act upon,
      #                            or a role (String or Symbol) that identifies one or more hosts.
      # @param [String, Command]   command The command to execute on *host*.
      # @param [Hash{Symbol=>String}] opts Options to alter execution.
      # @param [Proc]              block   Additional actions or assertions.
      #
      # @option opts [Array<Fixnum>, Fixnum] :desired_exit_codes (0) An array
      #   or integer exit code(s) that should be considered
      #   acceptable.  An error will be thrown if the exit code never
      #   matches one of the values in this list.
      # @option opts [Fixnum] :max_retries (60) number of times the
      #   command will be tried before failing
      # @option opts [Float] :retry_interval (1) number of seconds
      #   that we'll wait between tries
      # @option opts [Boolean] :verbose (false)
      def retry_on(host, command, opts = {}, &block)
        option_exit_codes     = opts[:desired_exit_codes]
        option_max_retries    = opts[:max_retries].to_i
        option_retry_interval = opts[:retry_interval].to_f
        desired_exit_codes    = option_exit_codes ? [option_exit_codes].flatten : [0]
        desired_exit_codes    = [0] if desired_exit_codes.empty?
        max_retries           = option_max_retries == 0 ? 60 : option_max_retries  # nil & "" both return 0
        retry_interval        = option_retry_interval == 0 ? 1 : option_retry_interval
        verbose               = true.to_s == opts[:verbose]

        log_prefix = host.log_prefix
        logger.debug "\n#{log_prefix} #{Time.new.strftime('%H:%M:%S')}$ #{command}"
        logger.debug "  Trying command #{max_retries} times."
        logger.debug ".", add_newline=false

        result = on host, command, {:acceptable_exit_codes => (0...127), :silent => !verbose}, &block
        num_retries = 0
        until desired_exit_codes.include?(result.exit_code)
          sleep retry_interval
          result = on host, command, {:acceptable_exit_codes => (0...127), :silent => !verbose}, &block
          num_retries += 1
          logger.debug ".", add_newline=false
          if (num_retries > max_retries)
            logger.debug "  Command \`#{command}\` failed."
            fail("Command \`#{command}\` failed.")
          end
        end
        logger.debug "\n#{log_prefix} #{Time.new.strftime('%H:%M:%S')}$ #{command} ostensibly successful."
        result
      end

      #Is semver-ish version a less than semver-ish version b
      #@param [String] a A version of the from '\d.\d.\d.*'
      #@param [String] b A version of the form '\d.\d.\d.*'
      #@return [Boolean] true if a is less than b, otherwise return false
      #
      #@note 3.0.0-160-gac44cfb is greater than 3.0.0, and 2.8.2
      #@note -rc being less than final builds is not yet implemented.
      def version_is_less a, b
        a_nums = a.split('-')[0].split('.')
        b_nums = b.split('-')[0].split('.')
        (0...a_nums.length).each do |i|
          if i < b_nums.length
            if a_nums[i] < b_nums[i]
              return true
            elsif a_nums[i] > b_nums[i]
              return false
            end
          else
            return false
          end
        end
        #checks all dots, they are equal so examine the rest
        a_rest = a.split('-', 2)[1]
        b_rest = b.split('-', 2)[1]
        if a_rest and b_rest and a_rest < b_rest
          return false
        elsif a_rest and not b_rest
          return false
        elsif not a_rest and b_rest
          return true
        end
        return false
      end

      #stops the puppet agent running on the host
      # @param [Host, Array<Host>, String, Symbol] agent    One or more hosts to act upon,
      #                            or a role (String or Symbol) that identifies one or more hosts.
      def stop_agent_on(agent)
        block_on agent do | host |
          vardir = agent.puppet['vardir']
          agent_running = true
          while agent_running
            result = on host, "[ -e '#{vardir}/state/agent_catalog_run.lock' ]", :acceptable_exit_codes => [0,1]
            agent_running = (result.exit_code == 0)
            sleep 2 unless agent_running
          end

          # The agent service is `pe-puppet` everywhere EXCEPT certain linux distros on PE 2.8
          # In all the case that it is different, this init script will exist. So we can assume
          # that if the script doesn't exist, we should just use `pe-puppet`
          result = on agent, "[ -e /etc/init.d/pe-puppet-agent ]", :acceptable_exit_codes => [0,1]
          agent_service = 'pe-puppet-agent'
          if result.exit_code != 0
            if agent['pe_ver'] && !version_is_less(agent['pe_ver'], '4.0')
              agent_service = 'puppet'
            else
              agent_service = 'pe-puppet'
            end
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
        retry_on(dashboard, "! curl --tlsv1 -k -I https://#{dashboard}/nodes/#{hostname} | grep '404 Not Found'")
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

      # Get a facter fact from a provided host
      #
      # @param [Host, Array<Host>, String, Symbol] host    One or more hosts to act upon,
      #                            or a role (String or Symbol) that identifies one or more hosts.
      # @param [String] name The name of the fact to query for
      # @!macro common_opts
      #
      # @return String The value of the fact 'name' on the provided host
      # @raise  [FailTest] Raises an exception if call to facter fails
      def fact_on(host, name, opts = {})
        result = on host, facter(name, opts)
        if result.kind_of?(Array)
          result.map { |res| res.stdout.chomp }
        else
          result.stdout.chomp
        end
      end

      # Get a facter fact from the default host
      # @see #fact_on
      def fact(name, opts = {})
        fact_on(default, name, opts)
      end

      #Run a curl command on the provided host(s)
      #
      # @param [Host, Array<Host>, String, Symbol] host    One or more hosts to act upon,
      #                            or a role (String or Symbol) that identifies one or more hosts.
      # @param [String, Command]   cmd The curl command to execute on *host*.
      # @param [Proc]              block   Additional actions or assertions.
      # @!macro common_opts
      #
      def curl_on(host, cmd, opts = {}, &block)
        if options.is_pe? #check global options hash
          on host, "curl --tlsv1 %s" % cmd, opts, &block
        else
          on host, "curl %s" % cmd, opts, &block
        end
      end

      # Write hiera config file on one or more provided hosts
      #
      # @param[Host, Array<Host>, String, Symbol] host    One or more hosts to act upon,
      #                           or a role (String or Symbol) that identifies one or more hosts.
      # @param[Array] One or more hierarchy paths
      def write_hiera_config_on(host, hierarchy)

        block_on host do |host|
          hiera_config=Hash.new
          hiera_config[:backends] = 'yaml'
          hiera_config[:yaml] = {}
          hiera_config[:yaml][:datadir] = host[:hieradatadir]
          hiera_config[:hierarchy] = hierarchy
          hiera_config[:logger] = 'console'
          create_remote_file host, host[:hieraconf], hiera_config.to_yaml
        end
      end

      # Write hiera config file for the default host
      # @see #write_hiera_config_on
      def write_hiera_config(hierarchy)
        write_hiera_config_on(default, hierarchy)
      end

      # Copy hiera data files to one or more provided hosts
      #
      # @param[Host, Array<Host>, String, Symbol] host    One or more hosts to act upon,
      #                           or a role (String or Symbol) that identifies one or more hosts.
      # @param[String]            Directory containing the hiera data files.
      def copy_hiera_data_to(host, source)
        scp_to host, File.expand_path(source), host[:hieradatadir]
      end

      # Copy hiera data files to the default host
      # @see #copy_hiera_data_to
      def copy_hiera_data(source)
        copy_hiera_data_to(default, source)
      end

    end
  end
end
