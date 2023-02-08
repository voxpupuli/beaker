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

    attr_reader :logger, :options, :network_manager
    def initialize
      @timestamp = Time.now
      # Initialize a logger object prior to parsing; this should be overwritten whence
      # the options are parsed and replaced with a new logger based on what is passed
      # in to configure the logger.
      @logger = Beaker::Logger.new
      @options = {}
    end

    def parse_options(args = ARGV)
      @options_parser = Beaker::Options::Parser.new
      @options = @options_parser.parse_args(args)
      @attribution = @options_parser.attribution
      @logger = Beaker::Logger.new(@options)
      InParallel::InParallelExecutor.logger = @logger
      @options_parser.update_option(:logger, @logger, 'runtime')
      @options_parser.update_option(:timestamp, @timestamp, 'runtime')
      @options_parser.update_option(:beaker_version, Beaker::Version::STRING, 'runtime')
      beaker_version_string = VERSION_STRING % @options[:beaker_version]

      # Some flags should exit early
      if @options[:help]
        @logger.notify(@options_parser.usage)
        exit(0)
      end
      if @options[:beaker_version_print]
        @logger.notify(beaker_version_string)
        exit(0)
      end
      if @options[:parse_only]
        print_version_and_options
        exit(0)
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

      self
    end

    # only call this method after parse_options has been executed.
    def print_version_and_options
      @logger.info("Beaker!")
      @logger.info(VERSION_STRING % @options[:beaker_version])
      @logger.info(@options.dump)
    end

    # Provision, validate and configure all hosts as defined in the hosts file
    def provision
      begin
        @hosts =  []
        initialize_network_manager
        @network_manager.proxy_package_manager
        @network_manager.validate
        @network_manager.configure
      rescue => e
        report_and_raise(@logger, e, "CLI.provision")
      end
      self
    end

    #Initialize the network manager so it can initialize hosts for testing for subcommands
    def initialize_network_manager
      begin
        @network_manager = Beaker::NetworkManager.new(@options, @logger)
        @hosts = @network_manager.provision
      rescue => e
        report_and_raise(@logger, e, "CLI.initialize_network_manager")
      end
    end

    # Run Beaker tests.
    #
    # - run pre-suite
    # - run tests
    # - run post-suite
    # - cleanup hosts
    def execute!
      print_version_and_options

      begin
        trap(:INT) do
          @logger.warn "Interrupt received; exiting..."
          exit(1)
        end

        # Setup perf monitoring if needed
        if /(aggressive)|(normal)/.match?(@options[:collect_perf_data].to_s)
          @perf = Beaker::Perf.new( @hosts, @options )
        end

        #pre acceptance  phase
        run_suite(:pre_suite, :fast)

        #testing phase
        begin
          run_suite(:tests, @options[:fail_mode])
        #post acceptance phase
        rescue => e
          #post acceptance on failure
          #run post-suite if we are in fail-slow mode
          if @options[:fail_mode].to_s.include?('slow')
            run_suite(:post_suite)
            @perf.print_perf_info if defined? @perf
          end
          raise e
        else
          #post acceptance on success
          run_suite(:post_suite)
          @perf.print_perf_info if defined? @perf
        end
      #cleanup phase
      rescue => e
        begin
          run_suite(:pre_cleanup)
        rescue => e
          # pre-cleanup failed
          @logger.error "Failed running the pre-cleanup suite."
        end

        #cleanup on error
        if /(never)|(onpass)/.match?(@options[:preserve_hosts].to_s)
          @logger.notify "Cleanup: cleaning up after failed run"
          if @network_manager
            @network_manager.cleanup
          end
        else
          preserve_hosts_file
        end

        print_reproduction_info( :error )

        @logger.error "Failed running the test suite."
        puts ''
        exit 1
      else
        begin
          run_suite(:pre_cleanup)
        rescue => e
          # pre-cleanup failed
          @logger.error "Failed running the pre-cleanup suite."
        end

        #cleanup on success
        if /(never)|(onfail)/.match?(@options[:preserve_hosts].to_s)
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
      end
    end

    #Run the provided test suite
    #@param [Symbol] suite_name The test suite to execute
    #@param [String] failure_strategy How to proceed after a test failure, 'fast' = stop running tests immediately, 'slow' =
    #                                 continue to execute tests.
    def run_suite(suite_name, failure_strategy = nil)
      if (@options[suite_name].empty?)
        @logger.notify("No tests to run for suite '#{suite_name}'")
        return
      end
      Beaker::TestSuite.new(
        suite_name, @hosts, @options, @timestamp, failure_strategy
      ).run_and_raise_on_failure
    end

    # Get the list of options that are not equal to presets.
    # @return Beaker::Options::OptionsHash
    def configured_options
      result = Beaker::Options::OptionsHash.new
      @attribution.each do |attribute, setter|
        if setter != 'preset'
          result[attribute] = @options[attribute]
        end
      end
      result
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
      dontpreserve = /HOSTS|logger|timestamp|log_prefix|_dated_dir|logger_sut/
      # set the pre/post/tests to be none
      @options[:pre_suite] = []
      @options[:post_suite] = []
      @options[:tests] = []
      @options[:pre_cleanup] = []
      preserved_hosts_filename = File.join(@options[:log_dated_dir], 'hosts_preserved.yml')

      hosts_yaml = @options
      hosts_yaml['HOSTS'] = combined_instance_and_options_hosts
      hosts_yaml['CONFIG'] = Beaker::Options::OptionsHash.new.merge(hosts_yaml['CONFIG'] || {})
      # save the rest of the options, excepting the HOSTS that we have already processed
      hosts_yaml['CONFIG'] = hosts_yaml['CONFIG'].merge(@options.reject{ |k,_v| dontpreserve.match?(k) })
      # remove copy of HOSTS information
      hosts_yaml['CONFIG']['provision'] = false
      File.open(preserved_hosts_filename, 'w') do |file|
        YAML.dump(hosts_yaml, file)
      end
      @options[:hosts_preserved_yaml_file] = preserved_hosts_filename
    end

    # Return a host_hash that is a merging of options host hashes with instance host objects
    # @return Hash
    def combined_instance_and_options_hosts
      hosts_yaml = @options
      newly_keyed_hosts_entries = {}
      hosts_yaml['HOSTS'].each do |host_name, file_host_hash|
        h = Beaker::Options::OptionsHash.new
        file_host_hash = h.merge(file_host_hash)
        @hosts.each do |host|
          if host_name.to_s == host.name.to_s
            newly_keyed_hosts_entries[host.hostname] = file_host_hash.merge(host.host_hash)
            break
          end
        end
      end
     newly_keyed_hosts_entries
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
