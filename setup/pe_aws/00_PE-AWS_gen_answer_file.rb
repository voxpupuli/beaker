test_name="Generate Puppet Enterprise answer files"
skip_test "Skipping answers file generation for non PE tests" and break unless ( options[:type] =~ /pe/ )
skip_test "Skipping answers file generation, --no-install selected" and break if ( options[:noinstall] )

portno=config['consoleport']
if (options[:type] =~ /pe_aws/) 
  certcmd='curl http://169.254.169.254/2008-02-01/meta-data/public-hostname'
else
  certcmd='uname | grep -i sunos > /dev/null && hostname || hostname -s'
end

common_a = %q[
q_install=y
q_puppet_cloud_install=n
q_puppet_symlinks_install=y
q_vendor_packages_install=y
]

# Agent base answers
agent_a = %Q[
q_puppetagent_certname=`#{certcmd}`
q_puppetagent_install='y'
q_puppetagent_server=MASTER
]

# Master base answers
master_a = %Q[
q_puppetmaster_certname=`#{certcmd}`
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
q_puppet_enterpriseconsole_inventory_hostname=`#{certcmd}`
q_puppet_enterpriseconsole_inventory_port=8140
q_puppet_enterpriseconsole_master_hostname=MASTER
]

dashboardhost = 'undefined'
FileUtils.rm Dir.glob('tmp/answers.*')  # Clean up all answer files
FileUtils.rm Dir.glob('tmp/hosts_ec2.*')  # Clean up ec2 hosts files
FileUtils.rm("tmp/answers.tar") if File::exists?("tmp/answers.tar")

hosts.each do |host|   # find our dashboard host for laster use
  dashboardhost = host if host['roles'].include? 'dashboard'
end

# create a list of hosts that are agents only -- for use by pssh
#File.open("tmp/hosts_ec2.agents", 'w') do |fh|
#  hosts.each do |host|
#    next if host['roles'].include? 'master'
#    next if host['roles'].include? 'dashboard'
#    fh.puts host
#  end
#end
# create a list of all hosts -- for use by pssh
#File.open("tmp/hosts_ec2.all", 'w') do |fh|
#  hosts.each do |host|
#    fh.puts host
#  end
#end

# Setup a single agent only answer file
# base answers: common + agent
# FIXME: static settings here prevent CP on agents.  
answers=common_a + agent_a + 'q_puppetagent_install=\'y\'' + "\n"
answers=answers + 'q_puppetmaster_install=\'n\'' + "\n"
answers=answers + 'q_puppetdashboard_install=\'n\'' + "\n"
answers=answers + 'q_puppet_cloud_install=\'n\'' + "\n"
File.open("tmp/answers.agent", 'w') do |fh|
  answers.split(/\n/).each do |line| 
    if line =~ /(q_puppetagent_server=)MASTER/ then
      line = $1+master
    end
    if line =~ /(q_puppetmaster_dashboard_hostname=)DASHBOARDHOST/ then
      line = $1+dashboardhost
    end
    if line =~ /(q_puppet_enterpriseconsole_master_hostname=)MASTER/ then
      line = $1+master
    end
    fh.puts line
  end
end

# Create role specific answer files for master, dashboard
hosts.each do |host|
  answers=''
  role=nil
  role_master=FALSE
  role_cloudpro=FALSE
  role_dashboard=FALSE
  role_master=TRUE    if host['roles'].include? 'master'
  role_cloudpro=TRUE  if host['roles'].include? 'cloudpro'
  role_dashboard=TRUE if host['roles'].include? 'dashboard'

  # base answers: common + agent
  answers=common_a + agent_a + 'q_puppetagent_install=\'y\'' + "\n"
  
  if role_master
    answers=answers + master_a + 'q_puppetmaster_install=\'y\'' + "\n"
    role='master'
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
  
  next unless role
  File.open("tmp/answers.#{role}", 'w') do |fh|
    answers.split(/\n/).each do |line| 
      if line =~ /(q_puppetagent_server=)MASTER/ then
        line = $1+master
      end
      if line =~ /(q_puppetmaster_enterpriseconsole_hostname=)DASHBOARD/ then
        line = $1+dashboardhost
      end
      if line =~ /(q_puppetdashboard_master_hostname=)MASTER/ then
        line = $1+master
      end
      fh.puts line
    end
  end
  # write host file for pssh
  File.open("tmp/hosts_ec2.#{role}", 'w') do |fh|
    fh.puts host
  end
end
