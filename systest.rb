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
config = read_config(options)
gen_answer_files(config)

if options[:mrpropper]
  prepper = TestWrapper.new(config)
  prepper.clean_hosts(config) if options[:mrpropper]  # Clean-up old install
end

perform_test_setup_steps(options, config)
test_summary = run_the_tests(options, config)
log.summarize(test_summary, config, options[:stdout]) unless options[:stdout_only]

if ! options[:stdout] then
  $stdout = org_stdout
end

## Back to our top level dir
FileUtils.cd($work_dir)
