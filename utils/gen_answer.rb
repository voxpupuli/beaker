#!/usr/bin/env ruby

require 'rubygems'
require 'net/ssh'
require 'net/scp'
require 'net/http'
require 'socket'
require 'optparse'
require 'systemu'
require 'require_all'


work_dir=FileUtils.pwd

# Parse command line args
def parse_args
  options = {}
  optparse = OptionParser.new do|opts|
    # Set a banner
    opts.banner = "Usage: harness.rb [-c || --config ] FILE"

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

# Agent base answers
agent_only_a = %w[
q_install=y
q_puppet_symlinks_install=y
q_puppetclient_certname=`hostname`
q_puppetclient_install=y
q_puppetclient_pluginsync=y
q_puppetclient_server=MASTER
q_puppetdashboard_install=n
q_puppetmaster_install=n
q_puppetclient_graph=y
]

# Master base answers
master_only_a = %w[
q_apr_install=n
q_install=y
q_puppet_symlinks_install=y
q_puppetclient_install=n
q_puppetdashboard_install=n
q_puppetmaster_certdnsnames=puppet:`hostname`
q_puppetmaster_certname=`hostname`
q_puppetmaster_install=y
q_puppetmaster_use_dashboard_classifier=n
q_puppetmaster_use_dashboard_reports=n
]


# Master and Dashboard answers
master_dashboard_a = %w[
q_apr_install=n
q_install=y
q_puppet_symlinks_install=y
q_puppetclient_install=n
q_puppetdashboard_database_install=y
q_puppetdashboard_httpd_port=3000
q_puppetdashboard_install=y
q_puppetmaster_certdnsnames=puppet:`hostname`
q_puppetmaster_certname=`hostname`
q_puppetmaster_dashboard_hostname=localhost
q_puppetmaster_dashboard_port=3000
q_puppetmaster_install=y
q_puppetmaster_use_dashboard_classifier=n
q_puppetmaster_use_dashboard_reports=y
]

# # Agent and Dashboard answers
# agent_dashboard_a = %w[
# q_install=y
# q_apr_install=n
# q_puppet_symlinks_install=y
# q_puppetclient_certname=puppet
# q_puppetclient_graph=y
# q_puppetclient_install=y
# q_puppetclient_pluginsync=y
# q_puppetclient_server=MASTER
# q_puppetdashboard_database_install=y
# q_puppetdashboard_httpd_port=3000
# q_puppetdashboard_install=y
# q_puppetmaster_install=n
# ]
# Dashboard base answers
# dashboard_only_a = %w[
# q_install=y
# q_puppet_symlinks_install=y
# q_puppetclient_install=n
# q_puppetdashboard_database_install=y
# q_puppetdashboard_httpd_port=3000
# q_puppetdashboard_install=y
# q_puppetmaster_install=n
# ]

###################################
#  Main
###################################
# Parse commnand line args
options=parse_args
puts "Using Config #{options[:config]}" if options[:config]
master=""

# Read config file
config = YAML.load(File.read(File.join(work_dir,options[:config])))

# Parse config for Master 
config["HOSTS"].each_key do|host|
  config["HOSTS"][host]['roles'].each do |role|
    if /master/ =~ role then         # Detect Puppet Master node
      master = host
    end
  end
end

# For all defined hosts...
config["HOSTS"].each_key do|host|
  role_agent=FALSE
  role_master=FALSE
  role_dashboard=FALSE
   
  # Access all "roles" for each host
  config["HOSTS"][host]['roles'].each do |role|
    role_agent=TRUE if role =~ /agent/
    role_master=TRUE if role =~ /master/
    role_dashboard=TRUE if role =~ /dashboard/
  end 

  # Host is only an Agent
  if role_agent then
    puts 'host is agent only'
    agent_only_a.each do |line|    # Insert Puppet master host name
      if line =~ /(q_puppetclient_server=)MASTER/ then
        line = $1+master
      end
      puts line
    end
  end

  # Host is a Master only - no Dashbord
  if role_master && !role_dashboard then
    puts 'host is master only'
    master_only_a.each do |line|
      puts line
    end
  end

  # Host is a Master and Dashboard
  if role_master && role_dashboard then
    puts 'host is master and dashboard'
    master_dashboard_a.each do |line|
      puts line
    end
  end

end

exit
