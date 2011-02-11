#!/usr/bin/env ruby

require 'rubygems'
require 'net/ssh'
require 'net/scp'
require 'net/http'
require 'socket'
require 'optparse'
require 'systemu'

Dir.glob(File.dirname(__FILE__) + '/lib/*.rb') {|file| require file}

# Where was I called from
$work_dir=FileUtils.pwd

# Run all tests discovered under a specific root
def run_tests_under(config, options, root)
  summary = {}
  (Dir[File.join(root, "**/*.rb")] + [root]).select { |f| File.file?(f) }.each do |name|
    puts "", "", "#{name} executing..."
    result = TestWrapper.new(config,options,name).run_test
    puts "#{name} returned: #{result.fail_flag}"
    summary[name] = result.fail_flag
  end
  return summary
end

###################################
#  Main
###################################
start_time = Time.new
org_stdout = $stdout      # save stdout file descriptor
test_summary={}           # hash to save test results

options=parse_args
if options[:tests].length < 1 then options[:tests] << 'tests' end

puts "Executing tests in #{options[:tests].join(', ')}"
if options[:config]
  puts "Using Config #{options[:config]}"
else
  fail "Argh!  There is no default for Config, specify one!"
end

# Setup logging
if ! options[:stdout_only] then
  log_file = setup_logs(start_time, options)
end

# Read config file
config = YAML.load(File.read(File.join($work_dir,options[:config])))

# Merge our default SSH options into the configuration.
ssh = {
  :config                => false,
  :paranoid              => false,
  :auth_methods          => ["publickey"],
  :keys                  => ["#{ENV['HOME']}/.ssh/id_rsa"],
  :port                  => 22,
  :user_known_hosts_file => "#{ENV['HOME']}/.ssh/known_hosts"
}
ssh.merge! config['CONFIG']['ssh'] if config['CONFIG']['ssh']
config['CONFIG']['ssh'] = ssh

# Generate installer answers files based on config
gen_answer_files(config)

# Add Puppet version to config
config["CONFIG"]["puppetver"]=puppet_version

if options[:mrpropper] 
  prepper = TestWrapper.new(config)
  prepper.clean_hosts(config) if options[:mrpropper]  # Clean-up old install
end


puts '=' * 78, "Performing test setup steps", ''
# PE signs certs during install; after/ValidateSignCert is not required.
# Not all test passes should exec after/*.  Need to another technique
# for post installer steps.
# ["setup/early", "setup/#{options[:type]}", "setup/late"].each do |root|
["setup/early", "setup/#{options[:type]}"].each do |root|
  run_tests_under(config, options, root).each do |test, result|
    unless result == 0 then
      puts "Warn: Setup action #{test} returned non-zero"
      # Installer often returns non-zero upon sucessful install and hence we should warn
      # vs bailing at this stage.
      # exit 1
    end
  end
end

options[:tests].each do |root|
  puts nil, '=' * 78, nil, "Running tests from #{root}"
  test_summary.merge! run_tests_under(config, options, root)
end

# Dump summary of test results
summarize(test_summary, start_time, config, options[:stdout])

if ! options[:stdout] then
  $stdout = org_stdout
end

## Back to our top level dir
FileUtils.cd($work_dir)
