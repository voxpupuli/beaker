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
        opts.on( '-c', '--config FILE', 'Use configuration FILE' ) do |file|
          @options[:config] = file
        end

        @defaults[:options_file] = nil
        opts.on( '-o', '--options-file FILE', 'Read options from FILE; if specified, this file should contain ruby code that evaluates to a hash.  The hash will be merged with the options hash that is built up from the command-line options; command-line options will be given precedence.' ) do |file|
          @options_from_file = parse_options_file(file)
        end

        @defaults[:type] = nil
        opts.on('--type TYPE', 'Select puppet install type (pe, pe_ro, git, gem) - no default ') do |type|
          unless File.directory?("setup/#{type}") then
            raise "Sorry, #{type} is not a known setup type!"
            exit 1
          end
          @options[:type] = type
        end

        @defaults[:tests] = []
        opts.on( '-t', '--tests DIR/FILE', 'Execute tests in DIR or FILE (defaults to "./tests")' ) do|dir|
          @options[:tests] ||= []
          @options[:tests] << dir
        end

        @defaults[:dry_run] = false
        opts.on( '-d', '--dry-run', "Just report what would be done on the targets" ) do |file|
          @options[:dry_run] = true
          $dry_run = true
        end

        @defaults[:debug] = false
        opts.on( '--debug', 'Enable full debugging' ) do |enable_debug|
          @options[:debug] = true
        end

        valid_rubies = %w{skip system 1.8.6 1.8.7}
        @defaults[:rvm] = 'skip'
        opts.on('--rvm VERSION', 'Specify Ruby version: system, 1.8.6, 1.8.7') do |rvm|
          unless valid_rubies.include? rvm
            raise "Sorry #{rvm} is not a valid Ruby version"
            exit 1
          end
          @options[:rvm] = rvm
          puts "RVM: #{@options[:rvm]}"
        end

        @defaults[:keyfile] = "#{ENV['HOME']}/.ssh/id_rsa"
        opts.on('--keyfile PATH TO SSH KEY', 'Specify alternate SSH key, defaults to ~/.ssh/id_rsa') do |key|
          @options[:keyfile] = key
        end

        @defaults[:keypair] = nil
        opts.on('--keypair name of cloud ID key', 'No default') do |key|
          @options[:keypair] = key
        end

        @defaults[:upgrade] = nil
        opts.on('--upgrade  VERSION', 'Specify the PE VERSION to upgrade *from*') do |upgrade|
          @options[:upgrade] = upgrade
        end

        @defaults[:snapshot] = nil
        opts.on('--snapshot NAME', 'Specify special VM snapshot name') do |snap|
          @options[:snapshot] = snap
        end

        @defaults[:pe_version] = nil
        opts.on('--pe-version version', 'Specify PE version to install, e.g.: 1.2.4 or 2.0.0') do |ver|
          @options[:pe_version] = ver
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

        @defaults[:vmrun] = nil
        opts.on( '--vmrun VM', 'VM revert and start VMs' ) do|vm|
          @options[:vmrun] = vm
        end

        @defaults[:installonly] = false
        opts.on( '--install-only', 'Perform install steps, run no tests' ) do
          @options[:installonly] = true
        end

        @defaults[:noinstall] = false
        opts.on( '--no-install', 'Skip install step' ) do
          @options[:noinstall] = true
        end

        @defaults[:ntpserver] = 'ntp.puppetlabs.lan'
        opts.on( '--ntp-server host', 'NTP server name' ) do|server|
          @options[:ntpserver] = server
        end

        @defaults[:timesync] = false
        opts.on( '--ntp', 'run ntpdate step' ) do
          @options[:timesync] = true
        end

        @defaults[:root_keys] = false
        opts.on('--root-keys', 'sync ~root/.ssh/authorized_keys') do
          @options[:root_keys] = true
        end

        @defaults[:dhcp_renew] = false
        opts.on('--dhcp-renew', 'perform dhcp lease renewal') do
          @options[:dhcp_renew] = true
        end

        @defaults[:pkg_repo] = false
        opts.on('--pkg-repo', 'configure packaging system repository') do
          @options[:pkg_repo] = true
        end

        @defaults[:stdout_only] = false
        opts.on('-s', '--stdout-only', 'log output to STDOUT but no files') do
          @options[:stdout_only] = true
        end

        @defaults[:quiet] = false
        opts.on('-q', '--quiet', 'don\'t log output to STDOUT') do
          @options[:quiet] = true
        end

        @defaults[:color] = true
        opts.on('--[no-]color', 'don\'t display color in log output') do |value|
          @options[:color] = value
        end

        @defaults[:random] = false
        opts.on('-r', '--random [RANDOM_KEY]', 'Randomize ordering of test files') do |random_key|
          @options[:random] = random_key || true
        end

        @defaults[:uninstall] = nil
        opts.on('--uninstall TYPE', 'Test the PE Uninstaller -- accepts either standard or full as options') do |value|
          @options[:uninstall] = value
        end

        @defaults[:xml] = false
        opts.on('-x', '--[no-]xml', 'Emit JUnit XML reports on tests') do |value|
          @options[:xml] = value
        end

        opts.on('--help', 'Display this screen' ) do
          puts opts
          exit
        end

        @defaults[:pre_script] = nil
        opts.on('--pre PATH/TO/SCRIPT', 'Pass steps to be run prior to setup') do |step|
          @options[:pre_script] = step
        end

        @defaults[:setup_dir] = nil
        opts.on('--setup-dir PATH/TO/SETUP/DIR',
                'An optional path to a directory containing extra "tests" to ' +
                 'be run during various phases of the test suite (e.g. "early",' +
                 '"pre_suite", "post_suite")') do |dir|
          @options[:setup_dir] = dir
        end

        @defaults[:helper] = nil
        opts.on('--helper PATH/TO/SCRIPT', 'A helper script (a la spec_helper) to require before tests execute') do |script|
          @options[:helper] = script
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
