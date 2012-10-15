module PuppetAcceptance
  class Options

    def self.options
      return @options
    end

    def self.parse_args
      return @options if @options

      @no_args = ARGV.empty? ? true : false

      @defaults = {}
      @options = {}
      @options_from_file = {}

      optparse = OptionParser.new do|opts|
        # Set a banner
        opts.banner = "Usage: #{File.basename($0)} [options...]"

        @defaults[:config] = nil
        opts.on '-c', '--config FILE',
                'Use configuration FILE' do |file|
          @options[:config] = file
        end

        @defaults[:options_file] = nil
        opts.on '-o', '--options-file FILE',
                'Read options from FILE',
                'This should evaluate to a ruby hash.',
                'CLI optons are given precedence.' do |file|
          @options_from_file = parse_options_file file
        end

        @defaults[:type] = nil
        opts.on '--type TYPE',
                'MANDATORY',
                'Select testing scenario type',
                '(eg. pe, git)' do |type|
          unless File.directory?("setup/#{type}") then
            raise "Sorry, #{type} is not a known setup type!"
            exit 1
          end
          @options[:type] = type
        end

        @defaults[:tests] = []
        opts.on  '-t', '--tests DIR/FILE',
                 'Execute tests in DIR or FILE',
                 '(default: "./tests")' do |dir|
          @options[:tests] ||= []
          @options[:tests] << dir
        end

        @defaults[:setup_dir] = nil
        opts.on '--setup-dir /SETUP/DIR/PATH',
                'Path to project specific setup steps',
                'Commonly used stages include:',
                '"early", "pre_suite", "post_suite"' do |dir|
          @options[:setup_dir] = dir
        end

        @defaults[:helper] = nil
        opts.on '--helper PATH/TO/SCRIPT',
                'Ruby file evaluated prior to tests',
                '(a la spec_helper)' do |script|
          @options[:helper] = script
        end

        @defaults[:pre_script] = nil
        opts.on '--pre PATH/TO/SCRIPT',
                'Pass steps to be run prior to setup' do |step|
          @options[:pre_script] = step
        end

        @defaults[:vmrun] = nil
        opts.on '--vmrun VM_PROVIDER',
                'Revert and start VMs',
                '(valid options: vsphere, fusion, blimpy)' do |vm|
          @options[:vmrun] = vm
        end

        @defaults[:snapshot] = nil
        opts.on '--snapshot NAME',
                'Specify VM snapshot to revert to' do |snap|
          @options[:snapshot] = snap
        end

        @defaults[:preserve_hosts] = false
        opts.on '--[no-]preserve-hosts',
                'Preserve cloud instances' do |value|
          @options[:preserve_hosts] = value
        end

        @defaults[:keypair] = nil
        opts.on '--keypair KEYPAIR_NAME',
                'Key pair for cloud provider credentials' do |key|
          @options[:keypair] = key
        end

        @defaults[:root_keys] = false
        opts.on '--root-keys',
                'Install puppetlabs pubkeys for superuser',
                '(default: false)' do |bool|
          @options[:root_keys] = bool
        end

        @defaults[:keyfile] = "#{ENV['HOME']}/.ssh/id_rsa"
        opts.on '--keyfile /PATH/TO/SSH/KEY',
                'Specify alternate SSH key',
                '(default: ~/.ssh/id_rsa)' do |key|
          @options[:keyfile] = key
        end

        @defaults[:puppet] = 'git://github.com/puppetlabs/puppet.git#HEAD'
        opts.on('-p', '--puppet URI', 'Select puppet git install URI',
                "  #{@options[:puppet]}",
                "    - URI and revision, default HEAD",
                "  just giving the revision is also supported"
                ) do |value|
          #@options[:type] = 'git'
          @options[:puppet] = value
        end

        @defaults[:facter] = 'git://github.com/puppetlabs/facter.git#HEAD'
        opts.on('-f', '--facter URI', 'Select facter git install URI',
                "  #{@options[:facter]}",
                "    - otherwise, as per the puppet argument"
                ) do |value|
          #@options[:type] = 'git'
          @options[:facter] = value
        end

        @defaults[:hiera] = nil
        opts.on('-h', '--hiera URI', 'Select Hiera git install URI',
                "  #{@options[:hiera]}"
                ) do |value|
          #@options[:type] = 'git'
          @options[:hiera] = value
        end

        @defaults[:hiera_puppet] = nil
        opts.on('--hiera-puppet URI', 'Select hiera-puppet git install URI',
                "  #{@options[:hiera_puppet]}"
                ) do |value|
          #@options[:type] = 'git'
          @options[:hiera_puppet] = value
        end

        # TODO: haven't really tested this well with multiple occurrences
        #  of the arg yet.
        @defaults[:yagr] = []
        opts.on('--yagr URI', 'Yet another git repo install URI; specify this option as many times as you like to add additional git repos to clone.'
                ) do |value|
          @options[:yagr] ||= []
          @options[:yagr] << value
        end



        @defaults[:modules] = []
        opts.on('-m', '--modules URI', 'Select puppet module git install URI') do |value|
          @options[:modules] ||= []
          @options[:modules] << value
        end

        @defaults[:plugins] = []
        opts.on('--plugin URI', 'Select puppet plugin git install URI') do |value|
          #@options[:type] = 'git'
          @options[:plugins] ||= []
          @options[:plugins] << value
        end

        @defaults[:stdout_only] = false
        opts.on '-s', '--stdout-only',
                'Log output to STDOUT only',
                '(default: false)' do |bool|
          @options[:stdout_only] = bool
        end

        @defaults[:quiet] = false
        opts.on '-q', '--[no-]quiet',
                'Do not log output to STDOUT',
                '(default: false)' do |bool|
          @options[:quiet] = bool
        end

        @defaults[:xml] = false
        opts.on '-x', '--[no-]xml',
                'Emit JUnit XML reports on tests',
                '(default: false)' do |bool|
          @options[:xml] = bool
        end

        @defaults[:color] = true
        opts.on '--[no-]color',
                'Do not display color in log output',
                '(default: true)' do |bool|
          @options[:color] = bool
        end

        @defaults[:debug] = false
        opts.on '--[no-]debug',
                'Enable full debugging',
                '(default: false)' do |bool|
          @options[:debug] = bool
        end

        @defaults[:random] = false
        opts.on '-r [SEED]', '--random [SEED]',
                'Randomize ordering of test files' do |seed|
          @options[:random] = seed || true
        end

        @defaults[:dry_run] = false
        opts.on  '-d', '--[no-]dry-run',
                 'Report what would happen on targets',
                 '(default: false)' do |bool|
          @options[:dry_run] = bool
          $dry_run = bool
        end

        @defaults[:ntpserver] = 'ntp.puppetlabs.lan'
        opts.on '--ntp-server HOST',
                'NTP server name',
                '(default: ntp.puppetlabs.lan' do |server|
          @options[:ntpserver] = server
        end

        @defaults[:timesync] = false
        opts.on '--[no-]ntp',
                'Sync time on SUTs before testing',
                '(default: false)' do |bool|
          @options[:timesync] = bool
        end

        @defaults[:dhcp_renew] = false
        opts.on '--[no-]dhcp-renew',
                'Perform dhcp lease renewal',
                '(default: false)' do |bool|
          @options[:dhcp_renew] = bool
        end

        @defaults[:pkg_repo] = false
        opts.on '--[no-]pkg-repo',
                'Configure packaging system repository',
                '(default: false)' do |bool|
          @options[:pkg_repo] = true
        end

        @defaults[:installonly] = false
        opts.on '--install-only',
                'Perform install steps, run no tests',
                '(default: false)' do |bool|
          @options[:installonly] = bool
        end

        @defaults[:noinstall] = false
        opts.on '--no-install',
                'Skip install step',
                '(default: false)' do |bool|
          @options[:noinstall] = bool
        end

        @defaults[:upgrade] = nil
        opts.on '--upgrade  VERSION',
                'P.E. VERSION to upgrade *from*' do |upgrade|
          @options[:upgrade] = upgrade
        end

        @defaults[:pe_version] = nil
        opts.on '--pe-version VERSION',
                'P.E. VERSION to install' do |version|
          @options[:pe_version] = version
        end

        @defaults[:uninstall] = nil
        opts.on '--uninstall TYPE',
                'Test the PE Uninstaller',
                '(valid options: full, standard)' do |type|
          @options[:uninstall] = type
        end

        @defaults[:rvm] = 'skip'
        opts.on '--rvm VERSION',
                'DEPRECATED' do |ruby|
          @options[:rvm] = ruby
        end


        opts.on('--help', 'Display this screen' ) do |yes|
          puts opts
          exit
        end
      end

      optparse.parse!

      # We have use the @no_args var because OptParse consumes ARGV as it parses
      # so we have to check the value of ARGV at the begining of the method,
      # let the options be set, then output usage.
      puts optparse if @no_args

      # merge in the options that we read from the file
      @options = @options_from_file.merge(@options)

      # merge in the defaults
      @options = @defaults.merge(@options)

      raise ArgumentError.new("Must specify the --type argument") unless @options[:type]

      @options[:tests] << 'tests' if @options[:tests].empty?

      @options
    end

    def self.parse_options_file(options_file_path)
      options_file_path = File.expand_path(options_file_path)
      unless File.exists?(options_file_path)
        raise ArgumentError, "Specified options file '#{options_file_path}' does not exist!"
      end
      # This eval will allow the specified options file to have access to our
      #  scope.  It is important that the variable 'options_file_path' is
      #  accessible, because some existing options files (e.g. puppetdb) rely on
      #  that variable to determine their own location (for use in 'require's, etc.)
      result = eval(File.read(options_file_path))
      unless result.is_a? Hash
        raise ArgumentError, "Options file '#{options_file_path}' must return a hash!"
      end

      result
    end
  end
end
