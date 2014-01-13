module Beaker
  class CLI
    GEMSPEC = File.join(File.expand_path(File.dirname(__FILE__)), "../../beaker.gemspec")
    VERSION_STRING = 
"      wWWWw
      |o o|
      | O |  %s!
      |(\")|
     / \\X/ \\
    |   V   |
    |   |   | "

    def initialize
      @options_parser = Beaker::Options::Parser.new
      @options = @options_parser.parse_args
      @logger = Beaker::Logger.new(@options)
      @options[:logger] = @logger

      if @options[:help]
        @logger.notify(@options_parser.usage)
        exit
      end
      if @options[:version]
        require 'rubygems' unless defined?(Gem)
        spec = Gem::Specification::load(GEMSPEC)
        @logger.notify(VERSION_STRING % spec.version)
        exit
      end
      @logger.info(@options.dump)

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

    def provision
      begin
        @hosts =  []
        @network_manager = Beaker::NetworkManager.new(@options, @logger)
        @hosts = @network_manager.provision
      rescue => e
        report_and_raise(@logger, e, "CLI.provision")
      end
    end

    def validate
      begin
        #validation phase
        Beaker::Utils::Validator.validate(@hosts, @logger)
      rescue => e
        report_and_raise(@logger, e, "CLI.validate")
      end
    end

    def setup
      @ntp_controller = Beaker::Utils::NTPControl.new(@options, @hosts)
      @setup = Beaker::Utils::SetupHelper.new(@options, @hosts)
      @repo_controller = Beaker::Utils::RepoControl.new(@options, @hosts)
      setup_steps = [[:timesync, "Sync time on hosts", Proc.new {@ntp_controller.timesync}],
                     [:root_keys, "Sync keys to hosts" , Proc.new {@setup.sync_root_keys}],
                     [:repo_proxy, "Proxy packaging repositories on ubuntu, debian and solaris-11", Proc.new {@repo_controller.proxy_config}],
                     [:add_el_extras, "Add Extra Packages for Enterprise Linux (EPEL) repository to el-* hosts", Proc.new {@repo_controller.add_el_extras}],
                     [:add_master_entry, "Update /etc/hosts on master with master's ip", Proc.new {@setup.add_master_entry}]]
      begin
        #setup phase
        setup_steps.each do |step| 
          if (not @options.has_key?(step[0])) or @options[step[0]]
            @logger.notify ""
            @logger.notify "Setup: #{step[1]}"
            step[2].call
          end
        end
      rescue => e
        report_and_raise(@logger, e, "CLI.setup")
      end
    end

    def execute!

      skip_cleanup = ["stop", "preserve"].include? @options[:fail_mode]
      begin
        trap(:INT) do
          @logger.warn "Interrupt received; exiting..."
          exit(1)
        end

        provision
        validate
        setup

        #pre acceptance  phase
        run_suite(:pre_suite, :fail_fast)

        #testing phase
        begin
          run_suite(:tests)
        #post acceptance phase
        rescue => e
          #post acceptance on failure
          #if we error then run the post suite as long as we aren't in fail-stop mode
          run_suite(:post_suite) unless skip_cleanup
          raise e
        else
          #post acceptance on success
          run_suite(:post_suite)
        end
      #cleanup phase
      rescue => e
        #cleanup on error
        #only do cleanup if we aren't in fail-stop mode
        @logger.notify "Cleanup: cleaning up after failed run"
        unless skip_cleanup
          if @network_manager
            @network_manager.cleanup
          end
        end
        raise "Failed to execute tests!"
      else
        #cleanup on success
        @logger.notify "Cleanup: cleaning up after successful run"
        if @network_manager
          @network_manager.cleanup
        end
      end
    end

    def run_suite(suite_name, failure_strategy = false)
      if (@options[suite_name].empty?)
        @logger.notify("No tests to run for suite '#{suite_name.to_s}'")
        return
      end
      Beaker::TestSuite.new(
        suite_name, @hosts, @options, failure_strategy
      ).run_and_raise_on_failure
    end

  end
end
