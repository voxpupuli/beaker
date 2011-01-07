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

$work_dir=FileUtils.pwd

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

###################################
#  Main
###################################
# Parse commnand line args
options=parse_args
puts "Executing tests in #{options[:testdir]}" if options[:testdir]
puts "Using Config #{options[:config]}" if options[:config]

# Read config file
config = YAML.load(File.read(File.join($work_dir,options[:config])))

# Print dump config
do_dump(config)
TestWrapper.new(config).prep_nodes

exit
