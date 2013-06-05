module PuppetAcceptance
  class CLI
    def initialize
      @options = PuppetAcceptance::Options.parse_args
      @logger = PuppetAcceptance::Logger.new(@options)
      @options[:logger] = @logger

      if @options[:config] then
        @logger.debug "Using Config #{@options[:config]}"
      else
        report_and_raise (@logger, RuntimeError.new("Argh!  There is no default for Config, specify one (-c or --config)!"), "CLI: initialize") 
      end

      @config = PuppetAcceptance::TestConfig.new(@options[:config], @options)

      if (@options[:helper])
        require File.expand_path(@options[:helper])
      end

      @hosts =  []
      @config['HOSTS'].each_key do |name|
        @hosts << PuppetAcceptance::Host.create(name, @options, @config)
      end
    end

    def execute!
      @vm_controller = PuppetAcceptance::Utils::VMControl.new(@options, @hosts, @config)
      @ntp_controller = PuppetAcceptance::Utils::NTPControl.new(@options, @hosts)
      @setup = PuppetAcceptance::Utils::SetupHelper.new(@options, @hosts)
      @repo_controller = PuppetAcceptance::Utils::RepoControl.new(@options, @hosts)

      setup_steps = [[:revert, "revert vms to snapshot", Proc.new {@vm_controller.revert}], 
                     [:timesync, "sync time on vms", Proc.new {@ntp_controller.timesync}],
                     [:root_keys, "sync keys to vms" , Proc.new {@setup.sync_root_keys}],
                     [:repo_proxy, "set repo proxy", Proc.new {@repo_controller.proxy_config}],
                     [:extra_repos, "add repo", Proc.new {@repo_controller.add_repos}],
                     [:add_master_entry, "update /etc/hosts on master with master's ip", Proc.new {@setup.add_master_entry}],
                     [:set_rvm_of_ruby, "set RVM of ruby", Proc.new {@setup.set_rvm_of_ruby}]]
      
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

        run_suite('pre-setup', pre_options, :fail_fast) if @options[:pre_script]
        run_suite('setup', setup_options, :fail_fast)
        run_suite('pre-suite', pre_suite_options)
        #testing phase
        begin
          run_suite('acceptance', @options) unless @options[:installonly]
        #post acceptance phase
        rescue => e
          #post acceptance on failure
          #if we error then run the post suite as long as we aren't in fail-stop mode
          run_suite('post-suite', post_suite_options) unless @options[:fail_mode] == "stop"
          raise e
        else
          #post acceptance on success
          run_suite('post-suite', post_suite_options)
        end
      #cleanup phase
      rescue => e
        #cleanup on error
        #only do cleanup if we aren't in fail-stop mode
        @logger.notify "Cleanup: cleaning up after failed run"
        if @options[:fail_mode] != "stop"
          @vm_controller.cleanup
          @hosts.each {|host| host.close }
        end
        raise "Failed to execute tests!"
      else
        #cleanup on success
        @logger.notify "Cleanup: cleaning up after successful run"
        @vm_controller.cleanup
        @hosts.each {|host| host.close }
      end
    end

    def run_suite(name, options, failure_strategy = false)
      #expand out tests, need to know contents of directories to determine if there are any tests
      test_files = []
      options[:tests].each do |root|
        if File.file? root then
          test_files << root
        else
          test_files += Dir.glob(
            File.join(root, "**/*.rb")
          ).select { |f| File.file?(f) }
        end
      end
      options[:tests] = test_files
      if (options[:tests].empty?)
        @logger.notify("No tests to run for suite '#{name}'")
        return
      end
      PuppetAcceptance::TestSuite.new(
        name, @hosts, options, @config, failure_strategy
      ).run_and_raise_on_failure
    end

    def setup_options
      setup_opts = nil
      if @options[:noinstall]
        setup_opts = @options.merge({
          :random => false,
          :tests  => ["#{puppet_acceptance_setup}/early" ] })

      elsif @options[:upgrade]
        setup_opts = @options.merge({
          :random => false,
          :tests  => ["#{puppet_acceptance_setup}/early",
                      "#{puppet_acceptance_setup}/pe_upgrade" ] })

      else
        setup_opts = build_suite_options("early")
        setup_opts[:tests] << "#{puppet_acceptance_setup}/#{@options[:type]}"
      end
      setup_opts
    end

    def pre_options
      @options.merge({
        :random => false,
        :tests => [ "#{puppet_acceptance_setup}/early",
                    @options[:pre_script] ] })
    end

    def pre_suite_options
      build_suite_options('pre_suite')
    end
    def post_suite_options
      build_suite_options('post_suite')
    end
    def cleanup_options
      build_suite_options('cleanup')
    end

    def build_suite_options(phase_name)
      tests = []
      if (File.directory?("#{puppet_acceptance_setup}/#{phase_name}"))
        tests << "#{puppet_acceptance_setup}/#{phase_name}"
      end
      if (@options[:setup_dir] and
          File.directory?("#{@options[:setup_dir]}/#{phase_name}"))
        tests << "#{@options[:setup_dir]}/#{phase_name}"
      end
      @options.merge({
         :random => false,
         :tests => tests })
    end

    def puppet_acceptance_setup
      @puppet_acceptance_setup ||= File.join(File.dirname(__FILE__), '..', '..', 'setup')
    end
  end
end
