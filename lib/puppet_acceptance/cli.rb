module PuppetAcceptance
  class CLI
    def initialize
      @options = PuppetAcceptance::Options.parse_args
      @logger = PuppetAcceptance::Logger.new(@options)
      @options[:logger] = @logger

      if @options[:config] then
        @logger.debug "Using Config #{@options[:config]}"
      else
        fail "Argh!  There is no default for Config, specify one (-c or --config)!"
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
      @vm_controller = PuppetAcceptance::VMController.new(@options, @hosts, @config)
      begin
        trap(:INT) do
          @logger.warn "Interrupt received; exiting..."
          exit(1)
        end
        #setup phase
        if @options[:revert]
          @logger.debug "Setup: revert vms to snapshot"
          @vm_controller.revert 
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
        if @options[:fail_mode] != "stop"
          @vm_controller.cleanup
          @hosts.each {|host| host.close }
        end
        raise "Failed to execute tests!"
      else
        #cleanup on success
        @vm_controller.cleanup
        @hosts.each {|host| host.close }
      end
    end

    def run_suite(name, options, failure_strategy = false)
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
