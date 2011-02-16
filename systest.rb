#!/usr/bin/env ruby

require 'rubygems'
require 'net/ssh'
require 'net/scp'
require 'net/http'
require 'socket'
require 'optparse'
require 'systemu'
require 'test/unit'

Test::Unit.run = true
Dir.glob(File.dirname(__FILE__) + '/lib/*.rb') {|file| require file}

# Where was I called from
$work_dir=FileUtils.pwd

###################################
#  Main
###################################
org_stdout = $stdout      # save stdout file descriptor

options=parse_args
log = Log.new(options)

if options[:config]
  Log.debug "Using Config #{options[:config]}"
else
  fail "Argh!  There is no default for Config, specify one!"
end

config = TestConfig.load_file(options[:config])
prepper = TestWrapper.new(config)

if options[:mrpropper]
  Log.debug "Cleaning Hosts of old install"
  prepper.clean_hosts(config) # Clean-up old install
end

prepper.gen_answer_files(config)

perform_test_setup_steps(log, options, config)

run_the_tests(log, options, config)

log.summarize(config, options[:stdout]) unless options[:stdout_only]

if ! options[:stdout] then
  $stdout = org_stdout
end

## Back to our top level dir
FileUtils.cd($work_dir)
