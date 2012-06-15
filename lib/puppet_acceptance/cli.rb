module PuppetAcceptance
  class CLI
    def initialize
      @options = PuppetAcceptance::Options.parse_args
      @options[:logger] = PuppetAcceptance::Logger.new(@options)
      @config = PuppetAcceptance::TestConfig.new(@options[:config], @options)
      @hosts = @config['HOSTS'].collect do |name, overrides|
        PuppetAcceptance::Host.create(name, overrides[:platform], @options,
                                      overrides, @config['CONFIG'])
      end
    end

    def execute!
      begin
      trap(:INT) do
        puts "Interrupt received; exiting..."
        exit(1)
      end

      ###################################
      #  Main
      ###################################

      unless @options[:config] then
        fail "Argh!  There is no default for Config, specify one!"
      end

      puts "Using Config #{@options[:config]}"


      if @options[:noinstall]
        setup_options = @options.merge({ :random => false,
                                        :tests  => ["setup/early", "setup/post"] })
      elsif @options[:upgrade]
        setup_options = @options.merge({ :random => false,
                                        :tests  => ["setup/early", "setup/pe_upgrade", "setup/post"] })
      elsif @options[:type] == 'cp_pe'
        setup_options = @options.merge({ :random => false,
                                        :tests => ["setup/early/01-vmrun.rb", "setup/cp_pe"] })
      elsif @options[:type] == 'pe_aws'
        setup_options = @options.merge({ :random => false,
                                        :tests => ["setup/pe_aws"] })
      elsif @options[:uninstall]
        setup_options = @options.merge({ :random => false,
                                        :tests  => ["setup/early", "setup/pe_uninstall/#{@options[:uninstall]}"] })
      else
        setup_options = @options.merge({ :random => false,
                                        :tests  => ["setup/early", "setup/#{@options[:type]}", "setup/post"] })
      end

        # Run any pre-flight scripts
        if @options[:pre_script]
          pre_opts = options.merge({ :random => false,
                                        :tests => [ 'setup/early', @options[:pre_script] ] })
          PuppetAcceptance::TestSuite.new('pre-setup', @hosts, pre_opts, @config, true).run_and_exit_on_failure
        end

        # Run the harness for install
        PuppetAcceptance::TestSuite.new('setup', @hosts, setup_options, @config, true).run_and_exit_on_failure

        # Run the tests
        unless @options[:installonly] then
          PuppetAcceptance::TestSuite.new('acceptance', @hosts, @options, @config).run_and_exit_on_failure
        end
      ensure
        @hosts.each {|host| host.close }
      end
    end
  end
end
