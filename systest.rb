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
  log_dir="#{time.month}"+"#{time.day}"+"#{time.year}"+ "_"+"#{time.hour}"+"#{time.min}"
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
    opts.banner = "Usage: harness.rb [-c || --config ] FILE [-d || --testdir] DIR"

    options[:testdir] = nil
    opts.on( '-d', '--testdir DIR', 'Execute tests in DIR' ) do|dir|
      options[:testdir] = dir
    end
    options[:config] = nil
    opts.on( '-c', '--config FILE', 'Use configuration FILE' ) do|file|
      options[:config] = file
    end

    opts.on( '-h', '--help', 'Display this screen' ) do
      puts opts
      exit
    end
  end
  optparse.parse!
  return options
end

def summarize(test_summary, time, config)
  sum_log = File.new("summary.txt", "w")
  $stdout = sum_log     # switch to logfile for output
  $stderr = sum_log
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
end

###################################
#  Main
###################################
start_time = Time.new
org_stdout = $stdout      # save stdout file descriptor
test_summary={}           # hash to save test results
# Parse commnand line args
options=parse_args
puts "Executing tests in #{options[:testdir]}" if options[:testdir]
puts "Using Config #{options[:config]}" if options[:config]

# Setup logging
log_dir = setup_logs(start_time, options[:config])

# Read config file
config = YAML.load(File.read(File.join($work_dir,options[:config])))

# Search for tests
list = FindTests.new(options[:testdir])
test_list = list.read_dir

# Iterate over test_list and execute
test_list.each do |test|
  if /^\d.*_(\w.*)\.rb/ =~ test then
    puts "\n#{$1} executing..."
    result = eval($1).new(config)
    puts "#{$1} returned: #{result.fail_flag}"
    test_summary[$1]=result.fail_flag
  end
end


# Dump summary of test results
summarize(test_summary, start_time, config)
$stdout = org_stdout
puts "Tests complete"

## Back to our top level dir
FileUtils.cd($work_dir)
