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
def setup_logs
  time = Time.new
  logdir="#{time.month}"+"#{time.day}"+"#{time.year}"+ "_"+"#{time.hour}"+"#{time.min}"
  FileUtils.mkdir(logdir)
  FileUtils.cd(logdir)
  $stdout.reopen("run.log","w")
  $stdout.sync = true
  $stderr.reopen($stdout)
  return logdir
end

# Parse command line args
def parse_args
  options = {}
  optparse = OptionParser.new do|opts|
    # Set a banner
    opts.banner = "Usage: harness.rb [-d || --testdir] DIR"

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


###################################
#  Main
###################################

# Parse commnand line args
options=parse_args
puts "Executing tests in #{options[:testdir]}" if options[:testdir]
puts "Using Config #{options[:config]}" if options[:config]

# Setup logging
logdir = setup_logs

# Read config file
config_file = ParseConfig.new(options[:config])
config = config_file.read_cfg

# Search for tests
list = FindTests.new("#{options[:testdir]}")
test_list = list.read_dir


# Iterate over test_list and execute
test_list.each do |test|
  if /^\d.*_(\w.*)\.rb/ =~ test then
    puts "\n\nRunning Test #{$1}"
    result = eval($1).new(config)
    puts "Test #{$1} returned: #{result.fail_flag}"
  end
end

# restore file descriptors
$stdout = STDOUT
$stderr = STDERR
## Back to our top level dir
FileUtils.cd($work_dir)
