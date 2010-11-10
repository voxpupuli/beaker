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

# Where was I called from
work_dir=FileUtils.pwd
puts "#{work_dir}"

# Build list of tests
def find_tests(work_dir)
  test_list = Dir.entries "#{work_dir}/tests2/"
  test_list.each do |test|
    next if test =~ /^\W/    # skip .hiddens and such
    puts "Found test #{test}"
    require "#{work_dir}/tests2/#{test}"
  end
  return test_list 
end


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



###################################
#  Main
###################################

# Read config file
config_file = ParseConfig.new("config_test")
config = config_file.read_cfg

# Setup logging
logdir = setup_logs

# Search for tests
test_list = find_tests(work_dir)

# Iterate over test_list and execute
test_list.each do |test|
  if /^\d.*_(\w.*)\.rb/ =~ test then
    puts "\n\nRunning Test #{$1}"
    result = eval($1).new(config)
    puts "Test #{$1} returned: #{result.fail_flag}"
  end
end

exit

# Santity checks
#result  = ValidatePass.new(config)
#puts "TEST RESULT #{result.fail_flag}\n\n"

#result = ValidateFail.new(config)
#puts "TEST RESULT #{result.fail_flag}\n\n";


# Call Test Setup 
# result = TestSetup.new(config)

# Call Puppet installer, passing config
# result = InstallPuppet.new(config)

# Run Validate Ruby Install
result = ValidateRuby.new(config)

# Run Validate Gem Install
result = ValidateGem.new(config)

# Run Validate Facter Install
result = ValidateFacter.new(config)

# Run Validate Puppet Install
result = ValidatePuppet.new(config)

# Run Validate Signing CA Certs
# result = ValidateSignCert.new(config)

# Run Validate HTTPD functionality
# result = ValidateHttpd.new(config)


# restore file descriptors
$stdout = STDOUT
$stderr = STDERR
## Back to our top level dir
FileUtils.cd(work_dir)
