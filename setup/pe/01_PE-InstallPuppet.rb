# Pre Test Setup stage
# SCP installer to host, Untar Installer
# Seperate install sections for PE 1.x and 2.x as paths, tarball names

version  = config['pe_ver']
test_name "Install Puppet #{version}"

confine :except, :platform => 'windows'

if options[:pe_version]
  distpath = "/opt/enterprise/dists/pe#{version}"
else
  distpath = "/opt/enterprise/dists"
end

if version =~ /^1.*/   #  Older version of PE, 1.x series
  logger.warn "Install PE 1.x series: #{version}"
  hosts.each do |host|
    platform = host['platform']
    # FIXME hack-o-rama: this is likely to be fragile and very PE 1.0, 1.1 specifc:
    # Tarballs have changed name rhel- is now el- and affects package naming
    # change el- to rhel- to match the old tarball naming/paths.
    # It gets worse, of course, as Centos differs from RHEL as well
    if version =~ /^1.1/ 
      if platform =~ /el-(.*)/ and host.name.include? 'cent'
         platform = "centos-#{$1}" 
      elsif platform =~ /el-(.*)/ and host.name.include? 'rhel'
        platform = "rhel-#{$1}" 
      end
    end
    host['dist'] = "puppet-enterprise-#{version}-#{platform}"
  
    unless File.file? "#{distpath}/#{host['dist']}.tar"
      logger.error "PE #{host['dist']}.tar not found, help!"
      logger.error ""
      logger.error "Make sure your configuration file uses the PE version string:"
      logger.error "  eg: rhel-5-x86_64  centos-5-x86_64"
      fail_test "Sorry, PE #{host['dist']}.tar file not found."
    end
  
    step "Pre Test Setup -- SCP install package to hosts"
    scp_to host, "#{distpath}/#{host['dist']}.tar", "/tmp"
    step "Pre Test Setup -- Untar install package on hosts"
    on host,"cd /tmp && tar xf #{host['dist']}.tar"
  end
  
  # Install Master first -- allows for auto cert signing
  hosts.each do |host|
    next if !( host['roles'].include? 'master' )
    step "SCP Master Answer file to #{host} #{host['dist']}"
    scp_to host, "tmp/answers.#{host}", "/tmp/#{host['dist']}"
    step "Install Puppet Master"
    on host,"cd /tmp/#{host['dist']} && ./puppet-enterprise-installer -a answers.#{host}"
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
  hosts.each do |host|
    platform = host['platform']
    host['dist'] = "puppet-enterprise-#{version}-#{platform}"

    # determine the distro tar name
    unless File.file? "#{distpath}/#{host['dist']}.tar.gz"
      logger.error "PE #{host['dist']}.tar.gz not found, help!"
      logger.error ""
      logger.error "Make sure your configuration file uses the PE version string:"
      logger.error "  eg: rhel-5-x86_64  centos-5-x86_64"
      fail_test "Sorry, PE #{host['dist']}.tar.gz file not found."
    end

    step "Pre Test Setup -- SCP install package to hosts"
    scp_to host, "#{distpath}/#{host['dist']}.tar.gz", "/tmp"
    step "Pre Test Setup -- Untar install package on hosts"
    on host,"cd /tmp && gunzip #{host['dist']}.tar.gz && tar xf #{host['dist']}.tar"
  end

  # Install Master first -- allows for auto cert signing
  hosts.each do |host|
    next if !( host['roles'].include? 'master' )
    step "SCP Master Answer file to #{host} #{host['dist']}"
    scp_to host, "tmp/answers.#{host}", "/tmp/#{host['dist']}"
    step "Install Puppet Master"
    if options[:installonly] 
      logger.warn "--install-only selected, triggering alternate umask 0027 for install."
      on host,"umask 0027 && cd /tmp/#{host['dist']} && ./puppet-enterprise-installer -a answers.#{host}"
    else
      on host,"cd /tmp/#{host['dist']} && ./puppet-enterprise-installer -a answers.#{host}"
    end
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
  end
end
