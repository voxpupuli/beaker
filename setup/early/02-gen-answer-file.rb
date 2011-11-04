test_name="Generate Puppet Enterprise answer files"

skip_test "Skipping answers file generation for non PE tests" and break unless ( options[:type] =~ /pe/ )
skip_test "Skipping answers file generation, --no-install selected" and break if ( options[:noinstall] )
portno=config['consoleport']

certcmd='uname | grep -i sunos > /dev/null && hostname || hostname -s'

common_a = %q[
q_install=y
q_puppet_cloud_install=n
q_puppet_symlinks_install=y
q_vendor_packages_install=y
]

# Agent base answers
agent_a = %Q[
q_puppetagent_certname=`uname | grep -i sunos > /dev/null && hostname || hostname -s`
q_puppetagent_install='y'
q_puppetagent_server=MASTER
]

# Master base answers
master_a = %Q[
q_puppetmaster_certname=`uname | grep -i sunos > /dev/null && hostname || hostname -s`
q_puppetmaster_dnsaltnames=`uname | grep -i sunos > /dev/null && hostname || hostname -s`,puppet
q_puppetmaster_enterpriseconsole_hostname=DASHBOARD
q_puppetmaster_enterpriseconsole_port=#{portno}
q_puppetmaster_forward_facts=y
q_puppetmaster_install=y
]

# Dashboard only answers
dashboard_a = %Q[
q_puppet_enterpriseconsole_auth_password='puppet'
q_puppet_enterpriseconsole_auth_user='console'
q_puppet_enterpriseconsole_database_install=y
q_puppet_enterpriseconsole_database_name='console'
q_puppet_enterpriseconsole_database_password='puppet'
q_puppet_enterpriseconsole_database_root_password='puppet'
q_puppet_enterpriseconsole_database_user='console'
q_puppet_enterpriseconsole_httpd_port=#{portno}
q_puppet_enterpriseconsole_install=y
q_puppet_enterpriseconsole_inventory_hostname=`uname | grep -i sunos > /dev/null && hostname || hostname -s`
q_puppet_enterpriseconsole_inventory_port=8140
q_puppet_enterpriseconsole_master_hostname=MASTER
q_puppet_enterpriseconsole_inventory_certname=`uname | grep -i sunos > /dev/null && hostname || hostname -s`
q_puppet_enterpriseconsole_inventory_dnsaltnames=MASTER
]

dashboardhost = nil
hosts.each do |host|  # Clean up all answer files that might conflict
  FileUtils.rm ["tmp/answers.#{host}"] if File.exists? "tmp/answers.#{host}"
end

hosts.each do |host|   # find our dashboard host for laster use
  dashboardhost = host if host['roles'].include? 'dashboard'
end

raise "No Dashboard host configured" unless dashboardhost
# For all defined hosts...
hosts.each do |host|
  answers=''
  role_agent=FALSE
  role_master=FALSE
  role_cloudpro=FALSE
  role_dashboard=FALSE
  role_agent=TRUE     if host['roles'].include? 'agent'
  role_master=TRUE    if host['roles'].include? 'master'
  role_cloudpro=TRUE  if host['roles'].include? 'cloudpro'
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
  
  if role_cloudpro
    answers=answers + 'q_puppet_cloud_install=\'y\'' + "\n"
  else
    answers=answers + 'q_puppet_cloud_install=\'n\'' + "\n"
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
      if line =~ /(q_puppetmaster_enterpriseconsole_hostname=)DASHBOARD/ then
        line = $1+dashboardhost
      end
      if line =~ /(q_puppet_enterpriseconsole_master_hostname=)MASTER/ then
        line = $1+master
      end
      if line =~ /(q_puppet_enterpriseconsole_inventory_dnsaltnames=)MASTER/ then
        line = $1+master+',puppetinventory'
      end
      fh.puts line
    end
  end
end
