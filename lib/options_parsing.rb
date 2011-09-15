class Options
  attr_reader :options

  def self.parse_args
    return @options if @options

    @options = {}
    optparse = OptionParser.new do|opts|
      # Set a banner
      opts.banner = "Usage: harness.rb [options...]"

      @options[:tests] = []
      opts.on( '-t', '--tests DIR/FILE', 'Execute tests in DIR or FILE (defaults to "./tests")' ) do|dir|
        @options[:tests] << dir
      end
      
      valid_rubies = %w{skip system 1.8.6 1.8.7}
      @options[:rvm] = 'skip'
      opts.on('--rvm VERSION', 'Specify Ruby version: system, 1.8.6, 1.8.7') do |rvm|
        unless valid_rubies.include? rvm
          Log.error "Sorry #{rvm} is not a valid Ruby version"
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

      @options[:type] = nil
      opts.on('--type TYPE', 'Select puppet install type (pe, pe_ro, git, gem) - no default ') do |type|
        unless File.directory?("setup/#{type}") then
          Log.error "Sorry, #{type} is not a known setup type!"
          exit 1
        end
        @options[:type] = type
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

      @options[:plugins] = []
      opts.on('--plugin URI', 'Select puppet plugin git install URI') do |value|
        #@options[:type] = 'git'
        @options[:plugins] << value
      end

      @options[:config] = nil
      opts.on( '-c', '--config FILE', 'Use configuration FILE' ) do|file|
        @options[:config] = file
      end

      opts.on( '--debug', 'Enable full debugging' ) do |enable_debug|
        if enable_debug
          Log.log_level = :debug
        else
          Log.log_level = :normal
        end
      end

      opts.on( '-d', '--dry-run', "Just report what would be done on the targets" ) do |file|
        $dry_run = true
      end

      @options[:vmrun] = nil
      opts.on( '--vmrun VM', 'VM revert and start VMs' ) do|vm|
        @options[:vmrun] = vm
      end

      @options[:installonly] = FALSE
      opts.on( '--install-only', 'Perform install steps, run no tests' ) do
        @options[:installonly]= TRUE
      end

      @options[:noinstall] = FALSE
      opts.on( '--no-install', 'Skip install step' ) do
        @options[:noinstall] = TRUE
      end

      @options[:mrpropper] = FALSE
      opts.on( '--mrpropper', 'Clean hosts' ) do
        @options[:mrpropper] = TRUE
      end

      @options[:notimesync] = FALSE
      opts.on( '--no-ntp', 'skip ntpdate step' ) do
        @options[:notimesync] = TRUE
      end

      @options[:stdout_only] = false
      opts.on('-s', '--stdout-only', 'log output to STDOUT but no files') do
        @options[:stdout_only] = true
      end

      Log.stdout = true
      opts.on('-q', '--quiet', 'don\'t log output to STDOUT') do
        Log.stdout = false
        @options[:quiet] = true
      end

      Log.color = true
      opts.on('--[no-]color', 'don\'t display color in log output') do |value|
        Log.color = value
      end

      @options[:random] = false
      opts.on('-r', '--random [RANDOM_KEY]', 'Randomize ordering of test files') do |random_key|
        @options[:random] = random_key || true
      end

      @options[:xml] = false
      opts.on('-x', '--[no-]xml', 'Emit JUnit XML reports on tests') do |value|
        @options[:xml] = value
      end

      opts.on( '-h', '--help', 'Display this screen' ) do
        puts opts
        exit
      end
    end
    optparse.parse!
    raise ArgumentError.new("Must specify the --type argument") unless @options[:type]

    @options[:tests] << 'tests' if @options[:tests].empty?

    @options
  end
end
