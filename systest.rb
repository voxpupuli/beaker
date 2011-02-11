#!/usr/bin/env ruby

require 'rubygems'
require 'net/ssh'
require 'net/scp'
require 'net/http'
require 'socket'
require 'optparse'
require 'systemu'

Dir.glob(File.dirname(__FILE__) + '/lib/*.rb') {|file| require file}

# Where was I called from
$work_dir=FileUtils.pwd

def log_dir(time)
  File.join("log", time.strftime("%F_%T"))
end

# Setup log dir
def setup_logs(time, options)
  return if options[:stdout_only]
  puts "Writing logs to #{log_dir(time)}/run.log"
  puts
  FileUtils.mkdir(log_dir(time))
  FileUtils.cp(options[:config],(File.join(log_dir(time),"config.yml")))

  latest = File.join("log", "latest")
  File.delete(latest) if File.symlink?(latest)
  if File.exists?(latest)
    puts "File log/latest is not a symlink; not overwriting"
  else
    File.symlink(File.basename(logdir(time)), latest)
  end

  log_file = File.join(log_dir(time), "run.log")
  run_log = File.new(log_file, "w")

  if ! options[:quiet]
    run_log = Tee.new(run_log)
  end

  $stdout = run_log
  $stderr = run_log
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
  return options
end

def summarize(test_summary, time, config, to_stdout)
  if to_stdout then
    puts "\n\n"
  else
    sum_log = File.new(File.join(log_dir(time), "/summary.txt"), "w")
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
# Run all tests discovered under a specific root
#
def run_tests_under(config, options, root)
  summary = {}
  Dir[File.join(root, "**/*.rb")].select { |f| File.file?(f) }.each do |name|
    puts "", "", "#{name} executing..."
    result = TestWrapper.new(config,options,name).run_test
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
if ! options[:stdout_only] then
  log_file = setup_logs(start_time, options)
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

# Add Puppet version to config
config["CONFIG"]["puppetver"]=puppet_version

if options[:mrpropper] 
  prepper = TestWrapper.new(config)
  prepper.clean_hosts(config) if options[:mrpropper]  # Clean-up old install
end


puts '=' * 78, "Performing test setup steps", ''
# PE signs certs during install; after/ValidateSignCert is not required.
# Not all test passes should exec after/*.  Need to another technique
# for post installer steps.
# ["setup/early", "setup/#{options[:type]}", "setup/late"].each do |root|
["setup/early", "setup/#{options[:type]}"].each do |root|
  run_tests_under(config, options, root).each do |test, result|
    unless result == 0 then
      puts "Warn: Setup action #{test} returned non-zero"
      # Installer often returns non-zero upon sucessful install and hence we should warn
      # vs bailing at this stage.
      # exit 1
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
  $stdout = org_stdout
end

## Back to our top level dir
FileUtils.cd($work_dir)
