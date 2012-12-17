test_name="PE 2.x: Generate Puppet Enterprise answer files"

skip_test "Skipping PE 2.x answers file generation for non PE tests" unless ( options[:type] =~ /pe/ )

skip_test "Skipping PE 2.x answers file generation, --no-install selected" if ( options[:noinstall] )

skip_test "Skipping PE 2.x answer file generation, PE version 1.2.x set" if ( options[:pe_version] =~ /1\.2/ )

portno=config['consoleport']

certcmd='uname | grep -i sunos > /dev/null && hostname || hostname -s'

common_a = %Q[
q_install=y
q_puppet_cloud_install=n
q_puppet_symlinks_install=y
q_vendor_packages_install=y
]

# FIXME: This string append should be refactored once answers are in a
# proper data structure instead of monolithis strings
common_a += "q_verify_packages='#{ENV['q_verify_packages']}'\n" if ENV['q_verify_packages']

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
q_puppet_enterpriseconsole_auth_database_user='mYu7hu3r'
q_puppet_enterpriseconsole_auth_database_password='~!@$%^*-/aZ'
q_puppet_enterpriseconsole_auth_database_name='console_auth'
q_puppet_enterpriseconsole_smtp_user_auth=y
q_puppet_enterpriseconsole_auth_password='#{ENV['q_puppet_enterpriseconsole_auth_password'] || '~!@$%^*-/aZ'}'
q_puppet_enterpriseconsole_database_install=y
q_puppet_enterpriseconsole_database_name='console'
q_puppet_enterpriseconsole_database_password='~!@$%^*-/aZ'
q_puppet_enterpriseconsole_database_root_password='~!@$%^*-/aZ'
q_puppet_enterpriseconsole_database_user='mYc0nS03u3r'
q_puppet_enterpriseconsole_install=y
q_puppet_enterpriseconsole_inventory_hostname=`uname | grep -i sunos > /dev/null && hostname || hostname -s`
q_puppet_enterpriseconsole_inventory_port=8140
q_puppet_enterpriseconsole_master_hostname=MASTER
q_puppet_enterpriseconsole_inventory_certname=`uname | grep -i sunos > /dev/null && hostname || hostname -s`
q_puppet_enterpriseconsole_inventory_dnsaltnames=MASTER
] + %Q[
q_puppet_enterpriseconsole_auth_user_email='#{ENV['q_puppet_enterpriseconsole_auth_user_email'] || 'admin@example.com'}'
q_puppet_enterpriseconsole_httpd_port=#{portno}
q_puppet_enterpriseconsole_smtp_host='#{ENV['q_puppet_enterpriseconsole_smtp_host'] || 'DASHBOARD'}'
q_puppet_enterpriseconsole_smtp_use_tls='#{ENV['q_puppet_enterpriseconsole_smtp_use_tls'] || 'n'}'
q_puppet_enterpriseconsole_smtp_port='#{ENV['q_puppet_enterpriseconsole_smtp_port'] || '25'}'
q_puppet_enterpriseconsole_smtp_username='#{ENV['q_puppet_enterpriseconsole_smtp_username'] || 'console-mailer@example.com'}'
q_puppet_enterpriseconsole_smtp_password='#{ENV['q_puppet_enterpriseconsole_smtp_password'] || '~!@#$%^*-/aZ'}'
]

upgrade_a = %Q[
q_rpm_verify_gpg='#{ENV['q_rpm_verify_gpg'] || 'y'}'
q_puppet_enterpriseconsole_database_root_password='#{ENV['q_puppet_enterpriseconsole_database_root_password'] || 'puppet' }'
q_puppet_cloud_install='#{ENV['q_puppet_cloud_install'] || 'y' }'
q_rubydevelopment_install='#{ENV['q_rubydevelopment_install'] || 'n' }'
q_upgrade_install_wrapper_modules='#{ENV['q_upgrade_install_wrapper_modules'] || 'n' }'
q_upgrade_installation='y'
q_puppet_enterpriseconsole_setup_auth_db='#{ENV['q_puppet_enterpriseconsole_setup_auth_db'] || 'y' }'
q_upgrade_remove_mco_homedir='#{ENV['q_upgrade_remove_mco_homedir'] || 'y' }'
q_vendor_packages_install='y'
q_puppet_enterpriseconsole_auth_database_name='console_auth'
q_puppet_enterpriseconsole_auth_database_password='puppet'
q_puppet_enterpriseconsole_auth_database_user='auth_user'
q_puppet_enterpriseconsole_auth_password='#{ENV['q_puppet_enterpriseconsole_auth_password'] || 'puppetized'}'
q_puppet_enterpriseconsole_auth_user_email='#{ENV['q_puppet_enterpriseconsole_auth_user_email'] || 'admin@example.com' }'
q_puppet_enterpriseconsole_setup_auth_db='y'
q_puppet_enterpriseconsole_smtp_host='#{ENV['q_puppet_enterpriseconsole_smtp_host'] || 'smtp.gmail.com' }'
q_puppet_enterpriseconsole_smtp_password='#{ENV['q_puppet_enterpriseconsole_smtp_password'] || 'password' }'
q_puppet_enterpriseconsole_smtp_port='#{ENV['q_puppet_enterpriseconsole_smtp_port'] || '25' }'
q_puppet_enterpriseconsole_smtp_use_tls='#{ENV['q_puppet_enterpriseconsole_smtp_use_tls'] || 'y' }'
q_puppet_enterpriseconsole_smtp_user_auth='#{ENV['q_puppet_enterpriseconsole_smtp_user_auth'] || 'y' }'
q_puppet_enterpriseconsole_smtp_username='#{ENV['q_puppet_enterpriseconsole_smtp_username'] || 'password' }'
]

dashboardhost = nil
hosts.each do |host|  # Clean up all answer files that might conflict
  FileUtils.rm ["tmp/answers.#{host}"] if File.exists? "tmp/answers.#{host}"
end

FileUtils.rm [ 'tmp/upgrade_a' ] if File.exists? 'tmp/upgrade_a'

hosts.each do |host|   # find our dashboard host for later use
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

  File.open 'tmp/upgrade_a', 'w' do |f|
    f.puts upgrade_a
  end

  File.open("tmp/answers.#{host}", 'w') do |fh|
    answers.split(/\n/).each do |line|
      if line =~ /(q_puppetagent_server=)MASTER/ then
        line = $1+master
      end
      if line =~ /(q_puppetmaster_enterpriseconsole_hostname=)DASHBOARD/ then
        line = $1+dashboardhost
      end
      if line =~ /(q_puppet_enterpriseconsole_smtp_host=)DASHBOARD/ then
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
