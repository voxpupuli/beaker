require 'resolv'

module PuppetAcceptance
  module DSL
    # This is the heart of the Puppet Acceptance DSL. Here you find a helper
    # to proxy commands to hosts, more commands to move files between hosts
    # and execute remote scripts, confine test cases to certain hosts and
    # prepare the state of a test case.
    #
    # To mix this is into a class you need the following:
    # * a method *hosts* that yields any hosts implementing
    #   {PuppetAcceptance::Host}'s interface to act upon.
    # * a method *logger* that yields a logger implementing
    #   {PuppetAcceptance::Logger}'s interface.
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

      # Move a file from a remote to a local path
      # @note If using {PuppetAcceptance::Host} for the hosts *scp* is not
      #   required on the system as it uses Ruby's net/scp library.  The
      #   net-scp gem however is required (and specified in the gemspec).
      #
      # @param [Host, #do_scp_from] host One or more hosts (or some object
      #                                  that responds like
      #                                  {PuppetAcceptance::Host#do_scp_from}.
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
      # @note If using {PuppetAcceptance::Host} for the hosts *scp* is not
      #   required on the system as it uses Ruby's net/scp library.  The
      #   net-scp gem however is required (and specified in the gemspec.
      #
      # @param [Host, #do_scp_to] host One or more hosts (or some object
      #                                that responds like
      #                                {PuppetAcceptance::Host#do_scp_to}.
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

      # Create a remote file out of a string
      # @note This method uses Tempfile in Ruby's STDLIB as well as {#scp_to}.
      #
      # @param [Host, #do_scp_to] hosts One or more hosts (or some object
      #                                 that responds like
      #                                 {PuppetAcceptance::Host#do_scp_from}.
      # @param [String] file_path A remote path to place *file_content* at.
      # @param [String] file_content The contents of the file to be placed.
      # @!macro common_opts
      #
      # @return [Result] Returns the result of the underlying SCP operation.
      def create_remote_file(hosts, file_path, file_content, opts = {})
        Tempfile.open 'puppet-acceptance' do |tempfile|
          File.open(tempfile.path, 'w') {|file| file.puts file_content }

          scp_to hosts, tempfile.path, file_path, opts
        end
      end

      # Move a local script to a remote host and execute it
      # @note this relies on {#on} and {#scp_to}
      #
      # @param [Host, #do_scp_to] host One or more hosts (or some object
      #                                that responds like
      #                                {PuppetAcceptance::Host#do_scp_from}.
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
        # {PuppetAcceptance::Host#temp_path} instead. TODO
        remote_path = File.join("", "tmp", File.basename(script))

        scp_to host, script, remote_path
        on host, remote_path, opts, &block
      end

      # Limit the hosts a test case is run against
      # @note This will modify the {PuppetAcceptance::TestCase#hosts} member
      #   in place unless an array of hosts is passed into it and
      #   {PuppetAcceptance::TestCase#logger} yielding an object that responds
      #   like {PuppetAcceptance::Logger#warn}, as well as
      #   {PuppetAcceptance::DSL::Outcomes#skip_test}, and optionally
      #   {PuppetAcceptance::TestCase#hosts}.
      #
      # @param [Symbol] type The type of confinement to do. Valid parameters
      #                      are *:to* to confine the hosts to only those that
      #                      match *criteria* or *:except* to confine the test
      #                      case to only those hosts that do not match
      #                      criteria.
      # @param [Hash{Symbol,String=>String,Regexp,Array<String,Regexp>}]
      #   criteria Specify the criteria with which a host should be
      #   considered for inclusion or exclusion.  The key is any attribute
      #   of the host that will be yielded by {PuppetAcceptance::Host#[]}.
      #   The value can be any string/regex or array of strings/regexp.
      #   The values are compared using {Enumerable#any?} so that if one
      #   value of an array matches the host is considered a match for that
      #   criteria.
      # @param [Array<Host>] host_array This creatively named parameter is
      #   an optional array of hosts to confine to.  If not passed in, this
      #   method will modify {PuppetAcceptance::TestCase#hosts} in place.
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


############################################################################
#
# Replacement methods for with_master_running_on, start_puppet_master,
# stop_puppet_master, and with_agent_running_on that do not have the same
# dependencies on TestCase or it's state
#
#############################################################################

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
      # @param [Array<Host>, Host] hosts One or more objects that act like Host
      #
      # @param [Symbol]            mode  Specifying a puppet mode to run in
      #
      # @param [Hash{Symbol=>String}]
      #                            config_opts Represent puppet settings.
      #                            Sections of the puppet.conf may be
      #                            specified, if no section is specified the
      #                            a puppet.conf file will be written with the
      #                            options put in a section named after [mode].
      #
      # @param [Block]             block The point of this method, yields so
      #                            tests may be ran. After the block is finished
      #                            puppet will revert to a previous state.
      #
      # @example A simple use case
      #     with_puppet_running_on( agents, :agent,
      #                              :server => master.name ) do |running_agents|
      #
      #       ...tests to be ran...
      #     end
      #
      # @example Fully utilizing the possiblities of config options
      #     with_puppet_running_on( host, :master,
      #                             :main => {:logdest => '/var/blah'},
      #                             :master => {:masterlog => '/elswhere'},
      #                             :agent => {:server => 'localhost'} ) do |running_master|
      #
      #       ...tests to be ran...
      #     end
      #
      # @api dsl
      # @!visibility private
      def with_puppet_running_on hosts, mode, config_opts = {}, &block
        if hosts.is_a? Array
          hosts.each do |h|
            with_puppet_running_on_a h, mode, config_opts, block
          end
        else
          with_puppet_running_on_a hosts, mode, config_opts, block
        end
      end

      # @see PuppetAcceptance::PuppetCommands#with_puppet_running_on
      # @note This is the method that contains the behavior needed by
      #       {#with_puppet_running_on}. {#with_puppet_running_on} delegates
      #       individual host actions to this method.
      #
      # @!visibility private
      def with_puppet_running_on_a host, mode, config_opts, &block
        #  begin
        #    backup_path = host.tmppath
        #    backup_file( host, host['puppetpath'], backup_path, 'puppet.conf' )
        #    replace_puppet_conf( host, mode, configuration_options )
        #    start_or_bounce_service( host, mode )

        #    yield

        #  ensure
        #    @network.on( host, "mv #{backup_puppetconf} #{host['puppetconf']}" )
        #  end
      end

      # @!visibility private
      def backup_file host, current_dir, new_dir, filename = 'puppet.conf'
        #old_location = current_dir + '/' + filename
        #new_location = new_dir + '/' + filename

        #@network.on( host, "cp #{old_location} #{new_location}" )
      end

      # @!visibility private
      def replace_puppet_conf( host, run_mode, configuration_options )
        #if configuration_options.values.all? {|v| v.is_a?( Hash ) }
        #  conf_opts.each_key do |key|
        #    host['puppetconf'][key] = conf_opts[key]
        #  end
        #else
        #  host['puppetconf'] = { mode => configuration_options }
        #end

        #@network.on( host, "echo #{host['puppetconf']} > #{host['puppetconfpath']}" )
      end

      # @!visibility private
      def start_or_bounce_service( host, service )
        #if host.running? mode
        #  host.restart mode
        #else
        #  host.start mode
        #end
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

#############################################################################
#
# These methods not only rely on PuppetAcceptance::TestCase#on but also rely
# on several other methods to retrieve collaboration SUTs and the state of
# previous PuppetAcceptance::DSL::Helpers#on results
#
#############################################################################

      # @note This method performs the following steps:
      #   1. issues start command for puppet master on specified host
      #   2. polls until it determines that the master has started successfully
      #   3. yields to a block of code passed by the caller
      #   4. runs a "kill" command on the master's pid (on the specified host)
      #   5. polls until it determines that the master has shut down successfully.
      #
      # @param [PuppetAcceptance::Host] host  the master host
      # @param [String] args                  a string containing all of the
      #   command line arguments that you would like for the puppet master to be
      #   started with.  Defaults to '--daemonize'. The following values will
      #   be added to the argument list if they are not explicitly set in your
      #   'args' parameter: '--daemonize', '--logdest="puppetvardir/log/puppetmaster.log"',
      #   '--dns_alt_names="puppet, $(facter hostname), $(puppet fqdn)"'
      #
      # @param [Hash] options only honors :preserve_ssl
      # @option options [Bool] :preserve_ssl whether or not to keep all
      #                                            hosts puppet ssl directories
      #                                            prior to starting the puppet master.
      #
      # @deprecated
      def with_master_running_on(host, args='--daemonize', options={}, &block)
        # they probably want to run with daemonize.  If they pass some other
        # arg/args but forget to re-include daemonize, we'll check and make sure
        # they didn't explicitly specify "no-daemonize", and, failing that,
        # we'll add daemonize to the args string
        if (args !~ /(?:--daemonize)|(?:--no-daemonize)/) then
          args << " --daemonize"
        end

        if (args !~ /--logdest/) then
          # master is not passed into this method, it assumes TestCase#master
          # helper is available
          args << " --logdest=\"#{master['puppetvardir']}/log/puppetmaster.log\""
        end

        if (args !~ /--dns_alt_names/) then
          args << " --dns_alt_names=\"puppet, $(facter hostname), $(facter fqdn)\""
        end

        unless options[:preserve_ssl]
          # hosts is not passed into this command, it assumes TestCase#hosts
          # helper is available
          on( hosts,
              host_command('rm -rf #{host["puppetpath"]}/ssl'),
              :silent => true )
        end

        # agents is not passed into this command, it assumes TestCase#agents
        # is available
        agents.each do |agent|
          if vardir = agent['puppetvardir']
            # we want to remove everything except the log and ssl directory (we
            # just got rid of ssl if preserve_ssl wasn't set, and otherwise want
            # to leave it)
            on agent, %Q[for i in "#{vardir}/*"; do echo $i; done | ] +
                      %Q[grep -v log| grep -v ssl | xargs rm -rf],
                      :silent => true
          end
        end

        on host, puppet_master('--configprint pidfile'), :silent => true

        # this is TestCase#stdout and it will, hopefully be set to the stdout of
        # the last executed TestCase#on method
        pidfile = stdout.chomp

        start_puppet_master(host, args, pidfile)

        # what are we yielding here? ...execution....
        yield if block
      ensure
        stop_puppet_master(host, pidfile)
      end

      # @deprecated
      def start_puppet_master(host, args, pidfile)
        on host, puppet_master(args)
        on(host,
           "kill -0 $(cat #{pidfile})",
           :acceptable_exit_codes => [0,1],
           :silent => true)

        # this is TestCase#exit_code which will hopefully be set to the
        # exit_code of the last TestCase#on method
        unless exit_code == 0
          raise "Puppet master doesn't appear to be running at all" 
        end

        timeout = 15
        wait_start = Time.now

        logger.notify "Waiting for master to start..."

        debug_opt = options[:debug] ? '-v ' : ''

        begin
          Timeout.timeout(timeout) do
            loop do
              # 7 is "Could not connect", which will happen before it's running
              # Here we try to explicitly set TestCase#result (it is the source
              # of TestCase#exit_code and TestCase#stdout) though TestCase#on
              # should set it automatically (and seems to work above)
              result = on( host,
                          "curl #{debug_opt}-s -k https://#{host}:8140",
                           :acceptable_exit_codes => [0,7],
                           :silent => true )

              # this is TestCase#exit_code which will hopefully be set to the
              # exit_code of the last TestCase#on method
              if exit_code == 0
                logger.debug( 'The Puppet Master has started.' )
                break
              elsif exit_code == 7
                logger.debug( 'The Puppet Master has yet to start...' )
                sleep 2
              end
            end
          end
        rescue Timeout::Error
          raise "Puppet master failed to start after #{timeout} seconds"
        end

        wait_finish = Time.now
        elapsed = wait_finish - wait_start

        logger.debug "Slept #{elapsed} sec. waiting for Puppet Master to start"
      end

      # @deprecated
      def stop_puppet_master(host, pidfile)
        on host, "[ -f #{pidfile} ]", :silent => true

        # this is TestCase#exit_code which will hopefully be set to the
        # exit_code of the last TestCase#on method
        unless exit_code == 0
          raise "Could not locate running puppet master"
        end

        on( host,
           "kill $(cat #{pidfile})",
           :acceptable_exit_codes => [0,1],
           :silent => true )

        timeout = 10
        wait_start = Time.now

        logger.notify "Waiting for master to stop..."

        begin
          Timeout.timeout(timeout) do
            loop do
              on( host,
                 "kill -0 $(cat #{pidfile})",
                  :acceptable_exit_codes => [0,1],
                  :silent => true )

              # this is TestCase#exit_code which will hopefully be set to the
              # exit_code of the last TestCase#on method
              if exit_code == 0
                logger.debug( 'The Puppet Master is still alive...' )
                sleep 2
              elsif exit_code == 1
                logger.debug( 'The Puppet Master has stopped.' )
                break
              end
            end
          end
        rescue Timeout::Error
          elapsed = Time.now - wait_start
          logger.warn(
            "Puppet master failed to stop after #{elapsed} seconds; " +
            'killing manually'
          )

          on host, "kill -9 $(cat #{pidfile})"
          on host, "rm -f #{pidfile}"
        end

        wait_finish = Time.now
        elapsed = wait_finish - wait_start

        logger.debug "Slept #{elapsed} sec. waiting for Puppet Master to stop"
      end

      # This method accepts a block and using the puppet resource 'host' will
      # setup host aliases before and after that block.
      #
      # A teardown step is also added to make sure unstubbing of the host is
      # removed always.
      #
      # @param machine [String] the host to execute this stub
      # @param hosts [Hash{String=>String}] a hash containing the host to ip
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
    end
  end
end
