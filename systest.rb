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
  Log.error "Interrupt received; exiting..."
  exit(1)
end

###################################
#  Main
###################################
options=Options.parse_args
unless options[:config] then
  fail "Argh!  There is no default for Config, specify one!"
end

Log.debug "Using Config #{options[:config]}"

config = TestConfig.load_file(options[:config])

if options[:noinstall] 
  setup_options = options.merge({ :random => false,
                                  :tests  => ["setup/early", "setup/post"] })
else
  setup_options = options.merge({ :random => false,
                                  :tests  => ["setup/early", "setup/#{options[:type]}", "setup/post"] })
end

TestSuite.new('setup', setup_options, config).run_and_exit_on_failure
TestSuite.new('acceptance', options, config).run_and_exit_on_failure

Log.notify "systest completed successfully, thanks."
exit 0
