# Agent base answers
agent_only_a = %q[
q_install=y
q_puppet_symlinks_install=y
q_puppetagent_certname=`uname | grep -i sunos > /dev/null && hostname || hostname -s`
q_puppetagent_install=y
q_puppetagent_pluginsync=y
q_puppetagent_server=MASTER
q_puppetdashboard_install=n
q_puppetmaster_install=n
q_rubydevelopment_install=y
q_vendor_packages_install=y
]

# Master base answers
master_only_a = %q[
q_install=y
q_puppet_symlinks_install=y
q_puppetagent_install=n
q_puppetdashboard_install=n
q_puppetmaster_certdnsnames=puppet:`uname | grep -i sunos > /dev/null && hostname || hostname -s`
q_puppetmaster_certname=`uname | grep -i sunos > /dev/null && hostname || hostname -s`
q_puppetmaster_dashboard_hostname=DASHBOARDHOST
q_puppetmaster_dashboard_port=3000
q_puppetmaster_install=y
q_puppetmaster_use_dashboard_classifier=y
q_puppetmaster_use_dashboard_reports=y
q_rubydevelopment_install=y
q_vendor_packages_install=y
]

# Agent and Dashboard answers
agent_dashboard_a = %q[
q_puppetdashboard_database_install=y
q_puppetdashboard_database_password=puppet
q_puppetdashboard_httpd_port=3000
q_puppetdashboard_install=y
q_puppetdashboard_database_name=dbdb
q_puppetdashboard_database_root_password=puppet
q_puppetdashboard_database_user=puppet
q_install=y
q_vendor_packages_install=y
q_puppet_symlinks_install=y
q_puppetagent_certname=`uname | grep -i sunos > /dev/null && hostname || hostname -s`
q_puppetagent_install=y
q_puppetagent_pluginsync=y
q_puppetagent_server=MASTER
q_puppetmaster_install=n
q_puppetagent_graph=y
q_rubydevelopment_install=y
]

# Dashboard only answers
dashboard_only_a = %q[
q_install='y'
q_puppet_symlinks_install='n'
q_puppetagent_install='n'
q_puppetdashboard_database_install='y'
q_puppetdashboard_database_name='dashboard'
q_puppetdashboard_database_password='puppet'
q_puppetdashboard_database_root_password='puppet'
q_puppetdashboard_database_user='dashboard'
q_puppetdashboard_httpd_port='3000'
q_puppetdashboard_install='y'
q_puppetmaster_install='n'
q_rubydevelopment_install='y'
q_vendor_packages_install='y'
]

master_dashboard_a= %q[
q_install=y
q_puppet_symlinks_install=y
q_puppetagent_install=n
q_puppetdashboard_install=n
q_puppetmaster_certdnsnames=puppet:`uname | grep -i sunos > /dev/null && hostname || hostname -s`
q_puppetmaster_certname=`uname | grep -i sunos > /dev/null && hostname || hostname -s`
q_puppetmaster_dashboard_hostname=DASHBOARDHOST
q_puppetmaster_dashboard_port=3000
q_puppetmaster_install=y
q_puppetmaster_use_dashboard_classifier=y
q_puppetmaster_use_dashboard_reports=y
q_rubydevelopment_install=y
q_vendor_packages_install=y
q_puppet_symlinks_install='n'
q_puppetagent_install='n'
q_puppetdashboard_database_install='y'
q_puppetdashboard_database_name='dashboard'
q_puppetdashboard_database_password='puppet'
q_puppetdashboard_database_root_password='puppet'
q_puppetdashboard_database_user='dashboard'
q_puppetdashboard_httpd_port='3000'
q_puppetdashboard_install='y'
q_puppetmaster_install='n'
q_rubydevelopment_install='y'
q_vendor_packages_install='y'
]

test_name="Generate Puppet Enterprise answer files"
puts "Skipping #{test_name}" unless ( options[:type] =~ /pe/ )

if ( options[:type] =~ /pe/ ) then
  dashboardhost = 'undefined'
  FileUtils.rm Dir.glob('tmp/q_*')  # Clean up all answer files
  FileUtils.rm("tmp/answers.tar") if File::exists?("tmp/answers.tar")

  hosts.each do |host|   # find our dashboard host for laster use
    dashboardhost = host if host['roles'].include? 'dashboard'
  end
  # For all defined hosts...
  hosts.each do |host|
    role_agent=FALSE
    role_master=FALSE
    role_dashboard=FALSE
    role_agent=TRUE     if host['roles'].include? 'agent'
    role_master=TRUE    if host['roles'].include? 'master'
    role_dashboard=TRUE if host['roles'].include? 'dashboard'
    # Host is only a Dashboard
    if !role_agent && !role_master && role_dashboard then
      step "Generate Dashboard only answer file"
      File.open("tmp/q_dashboard_only", 'w') do |fh|
        dashboard_only_a.split(/\n/).each do |line|    # Insert Puppet master host name
          if line =~ /(q_puppetagent_server=)MASTER/ then
            line = $1+master
          end
          fh.puts line
        end
      end
    end
    if role_agent && !role_master && !role_dashboard then
      step "Generate Agent only answer file"
      File.open("tmp/q_agent_only", 'w') do |fh|
        agent_only_a.split(/\n/).each do |line|    # Insert Puppet master host name
          if line =~ /(q_puppetagent_server=)MASTER/ then
            line = $1+master
          end
          fh.puts line
        end
      end
    end
    if !role_agent && role_master && !role_dashboard then
      step "Generate Master only answer file"
      File.open("tmp/q_master", 'w') do |fh|
        master_only_a.split(/\n/).each do |line|
          if line =~ /(q_puppetmaster_dashboard_hostname=)DASHBOARDHOST/ then
            line = $1+dashboardhost
          end
          fh.puts line
        end
      end
    end
    if role_agent && !role_master && role_dashboard then
      step "Generate Agent and Dashboard answer file"
      File.open("tmp/q_agent_and_dashboard", 'w') do |fh|
        agent_dashboard_a.split(/\n/).each do |line|
          if line =~ /(q_puppetagent_server=)MASTER/ then
            line = $1+master
          end
          fh.puts line
        end
      end
    end
    if !role_agent && role_master && role_dashboard then
      step "Generate Master and Dashboard answer file"
      File.open("tmp/q_master", 'w') do |fh|
        master_dashboard_a.split(/\n/).each do |line|
          if line =~ /(q_puppetagent_server=)MASTER/ then
            line = $1+master
          end
          if line =~ /(q_puppetmaster_dashboard_hostname=)DASHBOARDHOST/ then
            line = $1+dashboardhost
          end
          fh.puts line
        end
      end
    end

  end
  system("tar cf tmp/answers.tar tmp/q_*")
end #end if
