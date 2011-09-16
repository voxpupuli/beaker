
test_name="Generate Puppet Enterprise answer files"
skip_test "Skipping answers file generation for non PE tests" and break unless ( options[:type] =~ /pe/ )

common_a = %q[
q_install=y
q_puppet_symlinks_install=y
q_rubydevelopment_install=y
q_vendor_packages_install=y
]

# Agent base answers
agent_a = %q[
q_puppetagent_certname=`uname | grep -i sunos > /dev/null && hostname || hostname -s`
q_puppetagent_pluginsync=y
q_puppetagent_server=MASTER
]

# Master base answers
master_a = %Q[
q_puppetmaster_certdnsnames=puppet:`uname | grep -i sunos > /dev/null && hostname || hostname -s`:#{master}
q_puppetmaster_certname=`uname | grep -i sunos > /dev/null && hostname || hostname -s`
q_puppetmaster_dashboard_hostname=DASHBOARDHOST
q_puppetmaster_dashboard_port=3000
q_puppetmaster_use_dashboard_classifier=y
q_puppetmaster_use_dashboard_reports=y
q_puppetmaster_forward_facts=y
]

# Dashboard only answers
dashboard_a = %Q[
q_puppetdashboard_database_install='y'
q_puppetdashboard_database_name='dashboard'
q_puppetdashboard_database_password='puppet'
q_puppetdashboard_database_root_password='puppet'
q_puppetdashboard_database_user='dashboard'
q_puppetdashboard_httpd_port='3000'
q_puppetdashboard_master_hostname=MASTER
q_puppetdashboard_inventory_certname=`uname | grep -i sunos > /dev/null && hostname || hostname -s`
q_puppetdashboard_inventory_certdnsnames=`uname | grep -i sunos > /dev/null && hostname || hostname -s`:#{dashboard}
]

dashboardhost = 'undefined'
FileUtils.rm Dir.glob('tmp/answers.*')  # Clean up all answer files
FileUtils.rm("tmp/answers.tar") if File::exists?("tmp/answers.tar")

hosts.each do |host|   # find our dashboard host for laster use
  dashboardhost = host if host['roles'].include? 'dashboard'
end
# For all defined hosts...
hosts.each do |host|
  answers=''
  role_agent=FALSE
  role_master=FALSE
  role_dashboard=FALSE
  role_agent=TRUE     if host['roles'].include? 'agent'
  role_master=TRUE    if host['roles'].include? 'master'
  role_dashboard=TRUE if host['roles'].include? 'dashboard'

  answers=common_a
  if role_agent  
    answers=answers + agent_a + 'q_puppetagent_install=\'y\'' + "\n" 
  else 
    answers=answers + 'q_puppetagent_install=\'n\'' + "\n"
  end
  
  if role_master
    answers=answers + master_a + 'q_puppetmaster_install=\'y\'' + "\n"
  else
    answers=answers + 'q_puppetmaster_install=\'n\'' + "\n"
  end
  
  if role_dashboard
    answers=answers + dashboard_a + 'q_puppetdashboard_install=\'y\'' + "\n"
  else
    answers=answers + 'q_puppetdashboard_install=\'n\'' + "\n"
  end
  
  File.open("tmp/answers.#{host}", 'w') do |fh|
    answers.split(/\n/).each do |line| 
      if line =~ /(q_puppetagent_server=)MASTER/ then
        line = $1+master
      end
      if line =~ /(q_puppetmaster_dashboard_hostname=)DASHBOARDHOST/ then
        line = $1+dashboardhost
      end
      if line =~ /(q_puppetdashboard_master_hostname=)MASTER/ then
        line = $1+master
      end
      fh.puts line
    end
  end
end
#system("tar cf tmp/answers.tar tmp/answers.*")
