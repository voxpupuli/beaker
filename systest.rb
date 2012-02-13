#!/usr/bin/env ruby

require 'rubygems'
require 'net/ssh'
require 'net/scp'
require 'net/http'
require 'socket'
require 'optparse'
require 'systemu'
require 'test/unit'
require 'yaml'
require 'lib/host'

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
elsif options[:upgrade]
  setup_options = options.merge({ :random => false,
                                  :tests  => ["setup/early", "setup/pe_upgrade", "setup/post"] })
elsif options[:type] == 'cp_pe'
  setup_options = options.merge({ :random => false,
                                  :tests => ["setup/early/01-vmrun.rb", "setup/cp_pe"] })
elsif options[:type] == 'pe_aws'
  setup_options = options.merge({ :random => false,
                                  :tests => ["setup/pe_aws"] })
elsif options[:uninstall]
  setup_options = options.merge({ :random => false,
                                  :tests  => ["setup/early", "setup/pe_uninstall/#{options[:uninstall]}"] })
else
  setup_options = options.merge({ :random => false,
                                  :tests  => ["setup/early", "setup/#{options[:type]}", "setup/post"] })
end

# Generate hosts
hosts = config['HOSTS'].collect { |name,overrides| Host.create(name,overrides,config['CONFIG']) }
begin

  # Run any pre-flight scripts
  if options[:pre_script]
    pre_opts = options.merge({ :random => false,
                                  :tests => [ options[:pre_script] ] })
    TestSuite.new('pre-setup', hosts, pre_opts, config, TRUE).run_and_exit_on_failure
  end

  # Run the harness for install
  TestSuite.new('setup', hosts, setup_options, config, TRUE).run_and_exit_on_failure

  # Run the tests
  unless options[:installonly] then
    TestSuite.new('acceptance', hosts, options, config).run_and_exit_on_failure
  end
ensure
  hosts.each {|host| host.close }
end

Log.notify "systest completed successfully, thanks."
exit 0
