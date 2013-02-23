# Pre Test Setup stage
# SCP installer to host, Untar Installer
# Seperate install sections for PE 1.x and 2.x as paths, tarball names

version  = config['pe_ver']
test_name "Install Puppet #{version}"

confine :except, :platform => 'windows'

if version =~ /^1.*/   #  Older version of PE, 1.x series
  logger.warn "Install PE 1.x series: #{version}"
  
  # Install Master first -- allows for auto cert signing
  step "SCP Master Answer file to #{master} #{master['dist']}"
  scp_to master, "tmp/answers.#{master}", "/tmp/#{master['dist']}"
  step "Install Puppet Master"
  on master,"cd /tmp/#{master['dist']} && ./puppet-enterprise-installer -a answers.#{master}"
  if options[:debug]
    on master, "sed -e 's/# ARGV/ARGV/g' -i /var/opt/lib/pe-puppetmaster/config.ru"
    on master, "service pe-httpd restart"
  end

  # Install Puppet Agents
  step "Install Puppet Agent"
  hosts.each do |host|
    next if host['roles'].include? 'master'
    role_agent=FALSE
    role_dashboard=FALSE
    role_agent=TRUE     if host['roles'].include? 'agent'
    role_dashboard=TRUE if host['roles'].include? 'dashboard'

    step "SCP Answer file to dist tar dir"
    scp_to host, "tmp/answers.#{host}", "/tmp/#{host['dist']}"
    step "Install Puppet Agent"
    on host,"cd /tmp/#{host['dist']} && ./puppet-enterprise-installer -a answers.#{host}"
  end
else  # New versions of PE 2.x
  logger.warn "Install PE version #{version}"

  # Install Master first -- allows for auto cert signing
  step "SCP Master Answer file to #{master} #{master['dist']}"
  scp_to master, "tmp/answers.#{master}", "/tmp/#{master['dist']}"
  step "Install Puppet Master"
  if options[:installonly] 
    logger.warn "--install-only selected, triggering alternate umask 0027 for install."
    on master,"umask 0027 && cd /tmp/#{master['dist']} && ./puppet-enterprise-installer -a answers.#{master}"
  else
    on master,"cd /tmp/#{master['dist']} && ./puppet-enterprise-installer -a answers.#{master}"
  end
  if options[:debug]
    on master, "sed -e 's/# ARGV/ARGV/g' -i /var/opt/lib/pe-puppetmaster/config.ru"
    on master, "service pe-httpd restart"
  end

  # Install Puppet Agents
  step "Install Puppet Agent"
  hosts.each do |host|
    next if host['roles'].include? 'master'
    role_agent=FALSE
    role_dashboard=FALSE
    role_agent=TRUE     if host['roles'].include? 'agent'
    role_dashboard=TRUE if host['roles'].include? 'dashboard'

    step "SCP Answer file to dist tar dir"
    scp_to host, "tmp/answers.#{host}", "/tmp/#{host['dist']}"
    step "Install Puppet Agent"
    if options[:installonly] 
      logger.warn "--install-only selected, triggering alternate umask 0027 for install."
      on host,"umask 0027 && cd /tmp/#{host['dist']} && ./puppet-enterprise-installer -a answers.#{host}"
    else
      on host,"cd /tmp/#{host['dist']} && ./puppet-enterprise-installer -a answers.#{host}"
    end
    if options[:debug] and role_dashboard == TRUE
      on host, "sed -e 's/# ARGV/ARGV/g' -i /var/opt/lib/pe-puppetmaster/config.ru"
      on host, "service pe-httpd restart"
    end
  end
end
