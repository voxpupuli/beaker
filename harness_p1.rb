#!/usr/bin/env ruby

require 'rubygems'
require 'net/ssh'
require 'net/scp'
require 'net/http'
require 'socket'
require 'systemu'
require 'require_all'

# Import custom classes
require_all './lib'

# Build list of tests
test_list = Dir.entries 'tests1/'
test_list.each do |test|
  next if test =~ /^\W/    # skip .hiddens and such
  puts "Found test #{test}"
  require "tests1/#{test}"
end
puts

# Read config file
config_file = ParseConfig.new("config_test")
config = config_file.read_cfg

# Setup log dir
#time = Time.new
#logdir="#{time.month}"+"#{time.day}"+"#{time.year}"+ "_"+"#{time.hour}"+"#{time.min}"
#work_dir=FileUtils.pwd
#FileUtils.mkdir(logdir)
#FileUtils.cd(logdir)
#stdout = File.open("out.txt","w")
#stderr = File.open("err.txt","w")
#stdout.reopen("out.txt", "w")
#stderr.reopen("err.txt", "w")


###################################
#  Test Executiuon Starts Here
###################################

# Call Test Setup 
result = TestSetup.new(config)

# Call Puppet installer, passing config
result = InstallPuppet.new(config)

# Run Validate Puppet Version
# result = ValidateVersion.new(config)

# Run Validate Signing CA Certs
# result = ValidateSignCert.new(config)

# Run Validate HTTPD functionality
# result = ValidateHttpd.new(config)
#p result.fail_flag


# restore file descriptors
#$stdout = STDOUT
#$stderr = STDERR
## Back to our top level dir
#FileUtils.cd(work_dir)
