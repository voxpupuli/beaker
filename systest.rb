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
    opts.banner = "Usage: harness.rb [-c || --config ] FILE [-t || --tests] FILE/DIR [-s || --skip-dist] [ --mrpropper ]"

    options[:tests] = nil
    opts.on( '-t', '--tests DIR/FILE', 'Execute tests in DIR or FILE' ) do|dir|
      options[:tests] = dir
    end

    options[:config] = nil
    opts.on( '-c', '--config FILE', 'Use configuration FILE' ) do|file|
      options[:config] = file
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
  sum_log.close
end

###################################
#  Main
###################################
start_time = Time.new
org_stdout = $stdout      # save stdout file descriptor
test_summary={}           # hash to save test results
# Parse commnand line args
options=parse_args
puts "Executing tests in #{options[:tests]}" if options[:tests]
puts "Using Config #{options[:config]}" if options[:config]

# Setup logging
log_dir = setup_logs(start_time, options[:config])

# Read config file
config = YAML.load(File.read(File.join($work_dir,options[:config])))

# Generate installer answers files based on config
gen_answer_files(config)

# Run rake task to prep code to be scp'd to hosts
system("rake dist")

# Add Puppet version to config
config["CONFIG"]["puppetver"]=puppet_version

# Clean-up old install
clean_hosts(config) if options[:mrpropper]

# SCP updated test code to nodes
prep_nodes(config) if options[:dist]

# Generate test list from test file or dir
test_list=TestList.new(File.join($work_dir,options[:tests]))


# Execute Tests Here
test_list.each do |test|
  if /^\d.*_(\w.*)\.rb/ =~ test then             # parse the filename for class to call
    puts
    puts "\n#{$1} executing..."
    result = eval($1).new(config)                # Call the class, passing in ref to config
    puts "#{$1} returned: #{result.fail_flag}" 
    test_summary[$1]=result.fail_flag            # Add test result to test_summary hash for reporting
  end
end


# Dump summary of test results
summarize(test_summary, start_time, config)
log_dir.close
$stdout = org_stdout

## Back to our top level dir
FileUtils.cd($work_dir)
