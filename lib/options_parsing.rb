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
    opts.on('--type TYPE', 'Select puppet install type (pe, git, skip) - default "skip"') do
      |type|
      unless File.directory?("setup/#{type}") then
        puts "Sorry, #{type} is not a known setup type!"
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

    opts.on( '-d', '--dry-run', "Just report what would be done on the targets" ) do |file|
      $dry_run = true
    end

    options[:mrpropper] = FALSE
    opts.on( '--mrpropper', 'Clean hosts' ) do
      puts "Cleaning Hosts of old install"
      options[:mrpropper] = TRUE
    end

    options[:stdout_only] = FALSE
    opts.on('-s', '--stdout-only', 'log output to STDOUT but no files') do
      puts "Will log to STDOUT, not files..."
      options[:stdout_only] = TRUE
    end

    options[:quiet] = false
    opts.on('-q', '--quiet', 'don\'t log output to STDOUT') do
      options[:quiet] = true
    end

    opts.on( '-h', '--help', 'Display this screen' ) do
      puts opts
      exit
    end
  end
  optparse.parse!

  if options[:tests].length < 1 then options[:tests] << 'tests' end

  puts "Executing tests in #{options[:tests].join(', ')}"
  if options[:config]
    puts "Using Config #{options[:config]}"
  else
    fail "Argh!  There is no default for Config, specify one!"
  end

  return options
end

def read_config(options)
  config = YAML.load(File.read(File.join($work_dir,options[:config])))

  # Merge our default SSH options into the configuration.
  ssh = {
    :config                => false,
    :paranoid              => false,
    :auth_methods          => ["publickey"],
    :keys                  => ["#{ENV['HOME']}/.ssh/id_rsa"],
    :port                  => 22,
    :user_known_hosts_file => "#{ENV['HOME']}/.ssh/known_hosts"
  }
  ssh.merge! config['CONFIG']['ssh'] if config['CONFIG']['ssh']
  config['CONFIG']['ssh'] = ssh
  config["CONFIG"]["puppetver"]=puppet_version
  config
end
