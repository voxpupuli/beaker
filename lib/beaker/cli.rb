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
          if @options[:fail_mode] =~ /slow/
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
        if @options[:preserve_hosts] =~ /(never)/
          @logger.notify "Cleanup: cleaning up after failed run"
          if @network_manager
            @network_manager.cleanup
          end
        end

        @logger.error "\nFailed to execute tests!\n"
        print_reproduction_info( :error )

        exit 1
      else
        #cleanup on success
        if @options[:preserve_hosts] =~ /(never)|(onfail)/
          @logger.notify "Cleanup: cleaning up after successful run"
          if @network_manager
            @network_manager.cleanup
          end
        end
        print_reproduction_info( :debug ) if @logger.is_debug?
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

    def print_reproduction_info( log_level = :debug )
      puts ''
      @logger.send(log_level, "You can reproduce this run with:\n")
      @logger.send(log_level, @options[:command_line])
      puts ''
    end
  end
end
