module Beaker
  class CLI
    VERSION_STRING =
"      wWWWw
      |o o|
      | O |  %s!
      |(\")|
     / \\X/ \\
    |   V   |
    |   |   | "

    def initialize
      @timestamp = Time.now
      @options_parser = Beaker::Options::Parser.new
      @options = @options_parser.parse_args
      @logger = Beaker::Logger.new(@options)
      @options[:logger] = @logger
      @options[:timestamp] = @timestamp
      @execute = true

      if @options[:help]
        @logger.notify(@options_parser.usage)
        @execute = false
        return
      end
      if @options[:version]
        @logger.notify(VERSION_STRING % Beaker::Version::STRING)
        @execute = false
        return
      end
      @logger.info(@options.dump)
      if @options[:parse_only]
        @execute = false
        return
      end

      #add additional paths to the LOAD_PATH
      if not @options[:load_path].empty?
        @options[:load_path].each do |path|
          $LOAD_PATH << File.expand_path(path)
        end
      end
      @options[:helper].each do |helper|
        require File.expand_path(helper)
      end

    end

    #Provision, validate and configure all hosts as defined in the hosts file
    def provision
      begin
        @hosts =  []
        @network_manager = Beaker::NetworkManager.new(@options, @logger)
        @hosts = @network_manager.provision
        @network_manager.proxy_package_manager
        @network_manager.validate
        @network_manager.configure
      rescue => e
        report_and_raise(@logger, e, "CLI.provision")
      end
    end

    #Run Beaker tests.
    #
    # - provision hosts (includes validation and configuration)
    # - run pre-suite
    # - run tests
    # - run post-suite
    # - cleanup hosts
    def execute!

      if !@execute
        return
      end
      begin
        trap(:INT) do
          @logger.warn "Interrupt received; exiting..."
          exit(1)
        end

        provision

        # Setup perf monitoring if needed
        @perf = Beaker::Perf.new( @hosts, @options ) if @options[:collect_perf_data]

        errored = false

        #pre acceptance  phase
        run_suite(:pre_suite, :fast)

        #testing phase
        begin
          run_suite(:tests)
        #post acceptance phase
        rescue => e
          #post acceptance on failure
          #run post-suite if we are in fail-slow mode
          if @options[:fail_mode].to_s =~ /slow/
            run_suite(:post_suite)
          end
          raise e
        else
          #post acceptance on success
          run_suite(:post_suite)
        end
      #cleanup phase
      rescue => e
        #cleanup on error
        if @options[:preserve_hosts].to_s =~ /(never)|(onpass)/
          @logger.notify "Cleanup: cleaning up after failed run"
          if @network_manager
            @network_manager.cleanup
          end
        else
          preserve_hosts_file
        end

        @perf.print_perf_info if @options[:collect_perf_data]
        print_reproduction_info( :error )

        @logger.error "Failed running the test suite."
        puts ''
        exit 1
      else
        #cleanup on success
        if @options[:preserve_hosts].to_s =~ /(never)|(onfail)/
          @logger.notify "Cleanup: cleaning up after successful run"
          if @network_manager
            @network_manager.cleanup
          end
        else
          preserve_hosts_file
        end

        if @logger.is_debug?
          print_reproduction_info( :debug )
        end
        @perf.print_perf_info if @options[:collect_perf_data]
      end
    end

    #Run the provided test suite
    #@param [Symbol] suite_name The test suite to execute
    #@param [String] failure_strategy How to proceed after a test failure, 'fast' = stop running tests immediately, 'slow' =
    #                                 continue to execute tests.
    def run_suite(suite_name, failure_strategy = :slow)
      if (@options[suite_name].empty?)
        @logger.notify("No tests to run for suite '#{suite_name.to_s}'")
        return
      end
      Beaker::TestSuite.new(
        suite_name, @hosts, @options, @timestamp, failure_strategy
      ).run_and_raise_on_failure
    end

    # Sets aside the current hosts file for re-use with the --no-provision flag.
    # This is originally intended for use on a successful tests where the hosts
    # are preserved (the --preserve-hosts option is set accordingly).
    # It copies the current hosts file to the log directory, and rewrites the SUT
    # names to match their names during the finishing run.
    #
    # @return nil
    def preserve_hosts_file
      # things that don't belong in the preserved host file
      dontpreserve = /HOSTS|logger|timestamp|log_prefix|_dated_dir|logger_sut|pre_suite|post_suite|tests/
      preserved_hosts_filename = File.join(@options[:log_dated_dir], 'hosts_preserved.yml')
      FileUtils.cp(@options[:hosts_file], preserved_hosts_filename)
      hosts_yaml = YAML.load_file(preserved_hosts_filename)
      newly_keyed_hosts_entries = {}
      hosts_yaml['HOSTS'].each do |host_name, file_host_hash|
        h = Beaker::Options::OptionsHash.new
        file_host_hash = h.merge(file_host_hash)
        @hosts.each do |host|
          if host_name == host.name
            newly_keyed_hosts_entries[host.reachable_name] = file_host_hash.merge(host.host_hash)
            break
          end
        end
      end
      hosts_yaml['HOSTS'] = newly_keyed_hosts_entries
      hosts_yaml['CONFIG'] = Beaker::Options::OptionsHash.new.merge(hosts_yaml['CONFIG'] || {})
      # save the rest of the options, excepting the HOSTS that we have already processed
      hosts_yaml['CONFIG'] = hosts_yaml['CONFIG'].merge(@options.reject{ |k,v| k =~ dontpreserve })
      # remove copy of HOSTS information
      hosts_yaml['CONFIG']['provision'] = false
      File.open(preserved_hosts_filename, 'w') do |file|
        YAML.dump(hosts_yaml, file)
      end
      @options[:hosts_preserved_yaml_file] = preserved_hosts_filename
    end

    # Prints all information required to reproduce the current run & results to the log
    # @see #print_env_vars_affecting_beaker
    # @see #print_command_line
    #
    # @return nil
    def print_reproduction_info( log_level = :debug )
      print_command_line( log_level )
      print_env_vars_affecting_beaker( log_level )
    end

    # Prints Environment variables affecting the beaker run (those that
    # beaker introspects + the ruby env that beaker runs within)
    # @param [Symbol] log_level The log level (coloring) to print the message at
    # @example Print pertinent env vars using error leve reporting (red)
    #     print_env_vars_affecting_beaker :error
    #
    # @return nil
    def print_env_vars_affecting_beaker( log_level )
      non_beaker_env_vars =  [ 'BUNDLE_PATH', 'BUNDLE_BIN', 'GEM_HOME', 'GEM_PATH', 'RUBYLIB', 'PATH']
      env_var_map = non_beaker_env_vars.inject({}) do |memo, possibly_set_vars|
        set_var = Array(possibly_set_vars).detect {|possible_var| ENV[possible_var] }
        memo[set_var] = ENV[set_var] if set_var
        memo
      end

      env_var_map = env_var_map.merge(Beaker::Options::Presets.new.env_vars)

      @logger.send( log_level, "\nImportant ENV variables that may have affected your run:" )
      env_var_map.each_pair do |var, value|
        if value.is_a?(Hash)
          value.each_pair do | subvar, subvalue |
            @logger.send( log_level, "    #{subvar}\t\t#{subvalue}" )
          end
        else
          @logger.send( log_level, "    #{var}\t\t#{value}" )
        end
      end
    end

    # Prints the command line that can be called to reproduce this run
    # (assuming the environment is the same)
    # @param [Symbol] log_level The log level (coloring) to print the message at
    # @example Print pertinent env vars using error level reporting (red)
    #     print_command_line :error
    #
    # @note Re-use of already provisioned SUTs has been tested against the vmpooler & vagrant boxes.
    #     Fusion doesn't need this, as it has no cleanup steps. Docker is untested at this time.
    #     Please contact @electrical or the Puppet QE Team for more info, or for requests to support this.
    #
    # @return nil
    def print_command_line( log_level = :debug )
      @logger.send(log_level, "\nYou can reproduce this run with:\n")
      @logger.send(log_level, @options[:command_line])
      if @options[:hosts_preserved_yaml_file]
        set_docker_warning = false
        has_supported_hypervisor = false
        @hosts.each do |host|
          case host[:hypervisor]
          when /vagrant|fusion|vmpooler|vcloud/
            has_supported_hypervisor = true
          when /docker/
            set_docker_warning = true
          end
        end
        if has_supported_hypervisor
          reproducing_command = build_hosts_preserved_reproducing_command(@options[:command_line], @options[:hosts_preserved_yaml_file])
          @logger.send(log_level, "\nYou can re-run commands against the already provisioned SUT(s) with:\n")
          @logger.send(log_level, '(docker support is untested for this feature. please reference the docs for more info)') if set_docker_warning
          @logger.send(log_level, reproducing_command)
        end
      end
    end

    # provides a new version of the command given, edited for re-use with a
    # preserved host.  It does this by swapping the hosts file out for the
    # new_hostsfile argument and removing any previously set provisioning
    # flags that it finds
    # (we add +:provision => false+ in the new_hostsfile itself).
    #
    # @param [String] command Command line parameters to edit.
    # @param [String] new_hostsfile Path to the new hosts file to use.
    #
    # @return [String] The command line parameters edited for re-use
    def build_hosts_preserved_reproducing_command(command, new_hostsfile)
      command_parts = command.split(' ')
      replace_hosts_file_next = false
      reproducing_command = []
      command_parts.each do |part|
        if replace_hosts_file_next
          reproducing_command << new_hostsfile
          replace_hosts_file_next = false
          next
        elsif part == '--provision' || part == '--no-provision'
          next # skip any provisioning flag.  This is handled in the new_hostsfile itself
        elsif part == '--hosts'
          replace_hosts_file_next = true
        end
        reproducing_command << part
      end
      reproducing_command.join(' ')
    end
  end
end
