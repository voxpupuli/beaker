# Parse command line args
def parse_args
  options = {}
  optparse = OptionParser.new do|opts|
    # Set a banner
    opts.banner = "Usage: harness.rb [options...]"

    options[:tests] = []
    opts.on( '-t', '--tests DIR/FILE', 'Execute tests in DIR or FILE (defaults to "./tests")' ) do|dir|
      options[:tests] << dir
    end

    options[:type] = 'skip'
    opts.on('--type TYPE', 'Select puppet install type (pe, git, skip) - default "skip"') do |type|
      unless File.directory?("setup/#{type}") then
        Log.error "Sorry, #{type} is not a known setup type!"
        exit 1
      end
      options[:type] = type
    end

    options[:puppet] = 'git://github.com/puppetlabs/puppet.git#HEAD'
    opts.on('-p', '--puppet URI', 'Select puppet git install URI',
            "  #{options[:puppet]}",
            "    - URI and revision, default HEAD",
            "  just giving the revision is also supported"
            ) do |value|
      options[:type] = 'git'
      options[:puppet] = value
    end

    options[:facter] = 'git://github.com/puppetlabs/facter.git#HEAD'
    opts.on('-f', '--facter URI', 'Select facter git install URI',
            "  #{options[:facter]}",
            "    - otherwise, as per the puppet argument"
            ) do |value|
      options[:type] = 'git'
      options[:facter] = value
    end

    options[:config] = nil
    opts.on( '-c', '--config FILE', 'Use configuration FILE' ) do|file|
      options[:config] = file
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

    options[:mrpropper] = FALSE
    opts.on( '--mrpropper', 'Clean hosts' ) do
      options[:mrpropper] = TRUE
    end

    options[:stdout_only] = FALSE
    opts.on('-s', '--stdout-only', 'log output to STDOUT but no files') do
      options[:stdout_only] = TRUE
    end

    options[:quiet] = false
    opts.on('-q', '--quiet', 'don\'t log output to STDOUT') do
      options[:quiet] = true
    end

    options[:random] = false
    opts.on('-r', '--random [RANDOM_KEY]', 'Randomize ordering of test files') do |random_key|
      options[:random] = random_key || true
    end

    opts.on( '-h', '--help', 'Display this screen' ) do
      puts opts
      exit
    end
  end
  optparse.parse!

  options[:tests] << 'tests' if options[:tests].empty?

  return options
end
