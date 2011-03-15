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

trap(:INT) do
  $stderr.puts "Exiting..."
  exit(1)
end

###################################
#  Main
###################################
$org_stdout = $stdout      # save stdout file descriptor

options=Options.parse_args
unless options[:config] then
  fail "Argh!  There is no default for Config, specify one!"
end

Log.debug "Using Config #{options[:config]}"

config = TestConfig.load_file(options[:config])

setup_options = options.merge({ :random => false,
                                :tests  => ["setup/early", "setup/#{options[:type]}"] })
setup = TestSuite.new('setup', setup_options, config)
setup.run
unless setup.success? then
  $org_stdout.puts "Setup suite failed, exiting..."
  Log.error "Setup suite failed, exiting..."
  exit 1
end

acceptance = TestSuite.new('acceptance', options, config)
acceptance.run
unless acceptance.success? then
  $org_stdout.puts "Acceptance suite failed, exiting..."
  Log.error "Acceptance suite failed, exiting..."
  exit 1
end

$org_stdout.puts "systest completed successfully, thanks."
Log.info "systest completed successfully, thanks."
exit 0
