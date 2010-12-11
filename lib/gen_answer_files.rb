def gen_answer_files(config)

# Agent base answers
agent_only_a = %w[
q_vendor_packages_install=y
q_install=y
q_puppet_symlinks_install=y
q_puppetagent_certname=`hostname`
q_puppetagent_install=y
q_puppetagent_pluginsync=y
q_puppetagent_server=MASTER
q_puppetdashboard_install=n
q_puppetmaster_install=n
q_puppetagent_graph=y
]

# Master base answers
master_only_a = %w[
q_vendor_packages_install=y
q_install=y
q_puppet_symlinks_install=y
q_puppetagent_install=n
q_puppetdashboard_install=n
q_puppetmaster_certdnsnames=puppet:`hostname`
q_puppetmaster_certname=`hostname`
q_puppetmaster_install=y
q_puppetmaster_use_dashboard_classifier=n
q_puppetmaster_use_dashboard_reports=n
]


# Master and Dashboard answers
master_dashboard_a = %w[
q_vendor_packages_install=y
q_install=y
q_puppet_symlinks_install=y
q_puppetagent_install=n
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
# q_vendor_packages_install=y
# q_puppet_symlinks_install=y
# q_puppetagent_certname=puppet
# q_puppetagent_graph=y
# q_puppetagent_install=y
# q_puppetagent_pluginsync=y
# q_puppetagent_server=MASTER
# q_puppetdashboard_database_install=y
# q_puppetdashboard_httpd_port=3000
# q_puppetdashboard_install=y
# q_puppetmaster_install=n
# ]
# Dashboard base answers
# pashboard_only_a = %w[
# q_install=y
# q_vendor_packages_install=y
# q_puppet_symlinks_install=y
# q_puppetagent_install=n
# q_puppetdashboard_database_install=y
# q_puppetdashboard_httpd_port=3000
# q_puppetdashboard_install=y
# q_puppetmaster_install=n
# ]

master=""
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
  if role_agent && !role_dashboard then
    puts 'host is agent only'
    fh = File.new("#{$work_dir}/tarballs/q_agent_only.sh", 'w')
    agent_only_a.each do |line|    # Insert Puppet master host name
      if line =~ /(q_puppetagent_server=)MASTER/ then
        line = $1+master
      end
      fh.puts line
    end
    fh.close
  end

  # Host is a Master only - no Dashbord
  if role_master && !role_dashboard then
    puts 'host is master only'
    fh = File.new("#{$work_dir}/tarballs/q_master_only.sh", 'w')
    master_only_a.each do |line|
      fh.puts line
    end
    fh.close
  end

  # Host is a Master and Dashboard
  if role_master && role_dashboard then
    puts 'host is master and dashboard'
    fh = File.new("#{$work_dir}/tarballs/q_master_and_dashboard.sh", 'w')
    master_dashboard_a.each do |line|
      fh.puts line
    end
    fh.close
  end

end

end
