#!/usr/bin/env ruby

require 'rubygems' unless defined?(Gem)
require 'net/ssh'
require 'net/scp'
require 'net/http'
require 'socket'
require 'optparse'
require 'systemu'
require 'test/unit'
require 'yaml'

Test::Unit.run = true

Dir[
  File.expand_path(File.dirname(__FILE__)+'/lib/puppet_acceptance/*.rb')
].each do |file|
  require file
end

trap(:INT) do
  puts "Interrupt received; exiting..."
  exit(1)
end

###################################
#  Main
###################################
options = PuppetAcceptance::Options.parse_args

unless options[:config] then
  fail "Argh!  There is no default for Config, specify one!"
end

puts "Using Config #{options[:config]}"

config = PuppetAcceptance::TestConfig.new(options[:config], options)

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
hosts = config['HOSTS'].collect { |name,overrides| PuppetAcceptance::Host.create(name, overrides[:platform], options, overrides, config['CONFIG']) }
begin

  # Run any pre-flight scripts
  if options[:pre_script]
    pre_opts = options.merge({ :random => false,
                                  :tests => [ 'setup/early', options[:pre_script] ] })
    PuppetAcceptance::TestSuite.new('pre-setup', hosts, pre_opts, config, true).run_and_exit_on_failure
  end

  # Run the harness for install
  PuppetAcceptance::TestSuite.new('setup', hosts, setup_options, config, true).run_and_exit_on_failure

  # Run the tests
  unless options[:installonly] then
    PuppetAcceptance::TestSuite.new('acceptance', hosts, options, config).run_and_exit_on_failure
  end
ensure
  hosts.each {|host| host.close }
end

puts "systest completed successfully, thanks."
exit 0
