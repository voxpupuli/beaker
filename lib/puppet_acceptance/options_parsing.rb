module PuppetAcceptance
  class Options
    attr_reader :options

    def self.parse_args
      return @options if @options

      @no_args = ARGV.empty? ? true : false

      @options = {}
      optparse = OptionParser.new do|opts|
        # Set a banner
        opts.banner = "Usage: #{File.basename($0)} [options...]"

        @options[:config] = nil
        opts.on( '-c', '--config FILE', 'Use configuration FILE' ) do |file|
          @options[:config] = file
        end

        @options[:type] = nil
        opts.on('--type TYPE', 'Select puppet install type (pe, pe_ro, git, gem) - no default ') do |type|
          unless File.directory?("setup/#{type}") then
            raise "Sorry, #{type} is not a known setup type!"
            exit 1
          end
          @options[:type] = type
        end

        @options[:tests] = []
        opts.on( '-t', '--tests DIR/FILE', 'Execute tests in DIR or FILE (defaults to "./tests")' ) do|dir|
          @options[:tests] << dir
        end

        @options[:dry_run] = false
        opts.on( '-d', '--dry-run', "Just report what would be done on the targets" ) do |file|
          @options[:dry_run] = true
          $dry_run = true
        end

        @options[:debug] = false
        opts.on( '--debug', 'Enable full debugging' ) do |enable_debug|
          @options[:debug] = true
        end

        valid_rubies = %w{skip system 1.8.6 1.8.7}
        @options[:rvm] = 'skip'
        opts.on('--rvm VERSION', 'Specify Ruby version: system, 1.8.6, 1.8.7') do |rvm|
          unless valid_rubies.include? rvm
            raise "Sorry #{rvm} is not a valid Ruby version"
            exit 1
          end
          @options[:rvm] = rvm
          puts "RVM: #{@options[:rvm]}"
        end

        @options[:keyfile] = "#{ENV['HOME']}/.ssh/id_rsa"
        opts.on('--keyfile PATH TO SSH KEY', 'Specify alternate SSH key, defaults to ~/.ssh/id_rsa') do |key|
          @options[:keyfile] = key
        end

        @options[:keypair] = nil
        opts.on('--keypair name of cloud ID key', 'No default') do |key|
          @options[:keypair] = key
        end

        @options[:upgrade] = nil
        opts.on('--upgrade  VERSION', 'Specify the PE VERSION to upgrade *from*') do |upgrade|
          @options[:upgrade] = upgrade
        end

        @options[:snapshot] = nil
        opts.on('--snapshot NAME', 'Specify special VM snapshot name') do |snap|
          @options[:snapshot] = snap
        end

        @options[:pe_version] = nil
        opts.on('--pe-version version', 'Specify PE version to install, e.g.: 1.2.4 or 2.0.0') do |ver|
          @options[:pe_version] = ver
        end

        @options[:puppet] = 'git://github.com/puppetlabs/puppet.git#HEAD'
        opts.on('-p', '--puppet URI', 'Select puppet git install URI',
                "  #{@options[:puppet]}",
                "    - URI and revision, default HEAD",
                "  just giving the revision is also supported"
                ) do |value|
          #@options[:type] = 'git'
          @options[:puppet] = value
        end

        @options[:facter] = 'git://github.com/puppetlabs/facter.git#HEAD'
        opts.on('-f', '--facter URI', 'Select facter git install URI',
                "  #{@options[:facter]}",
                "    - otherwise, as per the puppet argument"
                ) do |value|
          #@options[:type] = 'git'
          @options[:facter] = value
        end

        @options[:hiera] = nil
        opts.on('-h', '--hiera URI', 'Select Hiera git install URI',
                "  #{@options[:hiera]}"
                ) do |value|
          #@options[:type] = 'git'
          @options[:hiera] = value
        end

        @options[:hiera_puppet] = nil
        opts.on('--hiera-puppet URI', 'Select hiera-puppet git install URI',
                "  #{@options[:hiera_puppet]}"
                ) do |value|
          #@options[:type] = 'git'
          @options[:hiera_puppet] = value
        end

        @options[:modules] = []
        opts.on('-m', '--modules URI', 'Select puppet module git install URI') do |value|
          @options[:modules] << value
        end

        @options[:plugins] = []
        opts.on('--plugin URI', 'Select puppet plugin git install URI') do |value|
          #@options[:type] = 'git'
          @options[:plugins] << value
        end

        @options[:vmrun] = nil
        opts.on( '--vmrun VM', 'VM revert and start VMs' ) do|vm|
          @options[:vmrun] = vm
        end

        @options[:installonly] = false
        opts.on( '--install-only', 'Perform install steps, run no tests' ) do
          @options[:installonly] = true
        end

        @options[:noinstall] = false
        opts.on( '--no-install', 'Skip install step' ) do
          @options[:noinstall] = true
        end

        @options[:ntpserver] = 'ntp.puppetlabs.lan'
        opts.on( '--ntp-server host', 'NTP server name' ) do|server|
          @options[:ntpserver] = server
        end

        @options[:timesync] = false
        opts.on( '--ntp', 'run ntpdate step' ) do
          @options[:timesync] = true
        end

        @options[:root_keys] = false
        opts.on('--root-keys', 'sync ~root/.ssh/authorized_keys') do
          @options[:root_keys] = true
        end

        @options[:dhcp_renew] = false
        opts.on('--dhcp-renew', 'perform dhcp lease renewal') do
          @options[:dhcp_renew] = true
        end

        @options[:pkg_repo] = false
        opts.on('--pkg-repo', 'configure packaging system repository') do
          @options[:pkg_repo] = true
        end

        @options[:stdout_only] = false
        opts.on('-s', '--stdout-only', 'log output to STDOUT but no files') do
          @options[:stdout_only] = true
        end

        @options[:quiet] = false
        opts.on('-q', '--quiet', 'don\'t log output to STDOUT') do
          @options[:quiet] = true
        end

        @options[:color] = true
        opts.on('--[no-]color', 'don\'t display color in log output') do |value|
          @options[:color] = value
        end

        @options[:random] = false
        opts.on('-r', '--random [RANDOM_KEY]', 'Randomize ordering of test files') do |random_key|
          @options[:random] = random_key || true
        end

        @options[:uninstall] = nil
        opts.on('--uninstall TYPE', 'Test the PE Uninstaller -- accepts either standard or full as options') do |value|
          @options[:uninstall] = value
        end

        @options[:xml] = false
        opts.on('-x', '--[no-]xml', 'Emit JUnit XML reports on tests') do |value|
          @options[:xml] = value
        end

        opts.on('--help', 'Display this screen' ) do
          puts opts
          exit
        end

        @options[:pre_script] = nil
        opts.on('--pre PATH/TO/SCRIPT', 'Pass steps to be run prior to setup') do |step|
          @options[:pre_script] = step
        end

        @options[:helper] = nil
        opts.on('--helper PATH/TO/SCRIPT', 'A helper script (a la spec_helper) to require before tests execute') do |script|
          require script
        end
      end

      optparse.parse!

      # We have use the @no_args var because OptParse consumes ARGV as it parses
      # so we have to check the value of ARGV at the begining of the method,
      # let the options be set, then output usage.
      puts optparse if @no_args

      raise ArgumentError.new("Must specify the --type argument") unless @options[:type]

      @options[:tests] << 'tests' if @options[:tests].empty?

      @options
    end
  end
end
