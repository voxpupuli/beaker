#!/usr/bin/env ruby

require 'rubygems'
require 'net/ssh'
require 'net/scp'
require 'net/http'
require 'socket'
require 'optparse'
require 'systemu'
require 'require_all'

# Import custom classes
require_all './lib'

# Where was I called from
$work_dir=FileUtils.pwd

# Setup log dir
def setup_logs(time, config_file)
  log_dir="#{time.month}"+"#{time.day}"+"#{time.year}"+ "_"+"#{time.hour}"+"#{time.min}"+"_"+"#{puppet_version}"+"_"+"#{config_file}"
  puts "Test logs will be written here: #{log_dir}"
  puts
  FileUtils.mkdir(log_dir)
  FileUtils.cp(config_file,(File.join(log_dir,"config.yml")))
  FileUtils.cd(log_dir)
  runlog = File.new("run.log", "w")
  $stdout = runlog                 # switch to logfile for output
  $stderr = runlog
  return runlog
end

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

    options[:dist] = FALSE
    opts.on( '--dist', 'scp test code to nodes' ) do
      puts "Will distributed upated remote test code"
      options[:dist] = TRUE
    end

    options[:stdout] = FALSE
    opts.on('-s', '--stdout', 'log output to STDOUT') do
      puts "Will log to STDOUT, not files..."
      options[:stdout] = TRUE
    end

    opts.on( '-h', '--help', 'Display this screen' ) do
      puts opts
      exit
    end
  end
  optparse.parse!
  return options
end

def summarize(test_summary, time, config, to_stdout)
  if to_stdout then
    puts "\n\n"
  else
    sum_log = File.new("summary.txt", "w")
    $stdout = sum_log     # switch to logfile for output
    $stderr = sum_log
  end
  puts "Test Pass Started: #{time}"
  puts
  puts "- Host Configuration Summary -" 
  do_dump(config)

  test_count=0
  test_failed=0
  test_passed=0
  test_summary.each do |test, result|
    test_count+=1
    test_passed+=1 if (result==0) 
    test_failed+=1 if (result!=0) 
  end
  puts
  puts "- Test Case Summary -" 
  puts "Attmpted: #{test_count}"
  puts "  Passed: #{test_passed}"
  puts "  Failed: #{test_failed}"
  puts
  puts "- Specific Test Case Status -"
  puts "Passed Tests Cases:"
  test_summary.each do |test, result|
    if ( result == 0 )
      puts "  Test Case #{test} reported: #{result}"
    end
  end
  puts "Failed Tests Cases:"
  test_summary.each do |test, result|
    if ( result != 0 )
      puts "  Test Case #{test} reported: #{result}"
    end
  end
  to_stdout or sum_log.close
end

#
# Return a list of .rb files in a directory tree
#
def test_list(path)
  if File.basename(path) =~ /^\W/
    [] # skip .hiddens and such
  elsif File.directory?(path) then
    puts "Looking for tests in #{path}"
    Dir.entries(path).
      collect { |entry| test_list(File.join(path,entry)) }.
      flatten.
      compact
  elsif path =~ /\.rb$/
    puts "Found #{path}"
    [path]
    #[path[/\S+\/(\S+)$/,1]]
  end
end

#
# Run all tests discovered under a specific root - typically from test_list
#
def run_tests_under(config, options, root)
  summary = {}
  test_list(File.join($work_dir,root)).each do |path|
    name = path.sub("#{$work_dir}/", '')
    puts "", "", "#{name} executing..."
    result = TestWrapper.new(config,options,path).run_test
    puts "#{name} returned: #{result.fail_flag}"
    summary[name] = result.fail_flag
  end
  return summary
end

###################################
#  Main
###################################
start_time = Time.new
org_stdout = $stdout      # save stdout file descriptor
test_summary={}           # hash to save test results
# Parse commnand line args
options=parse_args
if options[:tests].length < 1 then options[:tests] << 'tests' end
puts "Executing tests in #{options[:tests].join(', ')}"
if options[:config]
  puts "Using Config #{options[:config]}"
else
  fail "Argh!  There is no default for Config, specify one!"
end

# Setup logging
if ! options[:stdout] then
  log_dir = setup_logs(start_time, options[:config])
end

# Read config file
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

# Generate installer answers files based on config
gen_answer_files(config)

# Run rake task to prep code to be scp'd to hosts
system("rake dist")

# Add Puppet version to config
config["CONFIG"]["puppetver"]=puppet_version

if options[:mrpropper] || options[:dist]
  prepper = TestWrapper.new(config)
  prepper.clean_hosts(config) if options[:mrpropper]  # Clean-up old install
  prepper.prep_nodes          if options[:dist]       # SCP updated test code to nodes
end


puts '=' * 78, "Performing test setup steps", ''
# DEBUG
#["setup/early", "setup/#{options[:type]}", "setup/late"].each do |root|
["setup/early", "setup/#{options[:type]}"].each do |root|
  run_tests_under(config, options, root).each do |test, result|
    unless result == 0 then
      puts "Warn: Setup action #{test} returned non-zero"
      #exit 1
      puts "WARN: Setup action #{test} failed"
    end
  end
end

options[:tests].each do |root|
  puts nil, '=' * 78, nil, "Running tests from #{root}"
  test_summary.merge! run_tests_under(config, options, root)
end

# Dump summary of test results
summarize(test_summary, start_time, config, options[:stdout])

if ! options[:stdout] then
  log_dir.close
  $stdout = org_stdout
end

## Back to our top level dir
FileUtils.cd($work_dir)
