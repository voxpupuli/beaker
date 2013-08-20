module Beaker
  class CLI
    def initialize
      @options = Beaker::Options.parse_args
      @logger = Beaker::Logger.new(@options)
      @options[:logger] = @logger

      if not @options[:config] 
        report_and_raise(@logger, RuntimeError.new("Argh!  There is no default for Config, specify one (-c or --config)!"), "CLI: initialize") 
      end

      @logger.debug("Options")
      @options.each do |opt, val|
        if val and val != [] 
          @logger.debug("\t#{opt.to_s}:")
          if val.kind_of?(Array)
            val.each do |v|
              @logger.debug("\t\t#{v.to_s}")
            end
          else
            @logger.debug("\t\t#{val.to_s}")
          end
        end
      end

      @config = Beaker::TestConfig.new(@options[:config], @options)

      #add additional paths to the LOAD_PATH
      if not @options[:load_path].empty?
        @options[:load_path].each do |path|
          $LOAD_PATH << File.expand_path(path)
        end
      end
      @options[:helper].each do |helper|
        require File.expand_path(helper)
      end

      @hosts =  []
      @network_manager = Beaker::NetworkManager.new(@config, @options, @logger)
      @hosts = @network_manager.provision
      #validate that the hosts are correctly configured
      PuppetAcceptance::Utils::Validator.validate(@hosts, @logger)

    end

    def execute!
      @ntp_controller = Beaker::Utils::NTPControl.new(@options, @hosts)
      @setup = Beaker::Utils::SetupHelper.new(@options, @hosts)
      @repo_controller = Beaker::Utils::RepoControl.new(@options, @hosts)

      setup_steps = [[:timesync, "Sync time on hosts", Proc.new {@ntp_controller.timesync}],
                     [:root_keys, "Sync keys to hosts" , Proc.new {@setup.sync_root_keys}],
                     [:repo_proxy, "Proxy packaging repositories on ubuntu, debian and solaris-11", Proc.new {@repo_controller.proxy_config}],
                     [:add_el_extras, "Add Extra Packages for Enterprise Linux (EPEL) repository to el-* hosts", Proc.new {@repo_controller.add_el_extras}],
                     [:add_master_entry, "Update /etc/hosts on master with master's ip", Proc.new {@setup.add_master_entry}]]
      
      begin
        trap(:INT) do
          @logger.warn "Interrupt received; exiting..."
          exit(1)
        end
        #setup phase
        setup_steps.each do |step| 
          if (not @options.has_key?(step[0])) or @options[step[0]]
            @logger.notify ""
            @logger.notify "Setup: #{step[1]}"
            step[2].call
          end
        end

        #pre acceptance  phase
        run_suite('pre-suite', @options.merge({:tests => @options[:pre_suite]}), :fail_fast)
        #testing phase
        begin
          run_suite('acceptance', @options)
        #post acceptance phase
        rescue => e
          #post acceptance on failure
          #if we error then run the post suite as long as we aren't in fail-stop mode
          run_suite('post-suite', @options.merge({:tests => @options[:post_suite]})) unless @options[:fail_mode] == "stop"
          raise e
        else
          #post acceptance on success
          run_suite('post-suite', @options.merge({:tests => @options[:post_suite]}))
        end
      #cleanup phase
      rescue => e
        #cleanup on error
        #only do cleanup if we aren't in fail-stop mode
        @logger.notify "Cleanup: cleaning up after failed run"
        if @options[:fail_mode] != "stop"
          @network_manager.cleanup
        end
        raise "Failed to execute tests!"
      else
        #cleanup on success
        @logger.notify "Cleanup: cleaning up after successful run"
        @network_manager.cleanup
      end
    end

    def run_suite(name, options, failure_strategy = false)
      if (options[:tests].empty?)
        @logger.notify("No tests to run for suite '#{name}'")
        return
      end
      Beaker::TestSuite.new(
        name, @hosts, options, @config, failure_strategy
      ).run_and_raise_on_failure
    end

  end
end
