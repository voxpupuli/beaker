# PE upgrader test
version  = config['pe_ver']
upgrade_v = options[:upgrade]

test_name "Upgrade #{upgrade_v} to #{version}"
hosts.each do |host|
  platform = host['platform']

  # determine the distro tar name
  dist_tar = "puppet-enterprise-#{version}-#{platform}.tar"
  dist_gz = "#{dist_tar}.gz"
  unless File.file? "/opt/enterprise/dists/#{dist_gz}"
    logger.error "PE #{dist_gz} not found, help!"
    logger.error ""
    logger.error "Make sure your configuration file uses the PE version string:"
    logger.error "  eg: rhel-5-x86_64  centos-5-x86_64"
    fail_test "Sorry, PE #{dist_gz} file not found."
  end

  step "Pre Test Setup -- SCP install package to hosts"
  scp_to host, "/opt/enterprise/dists/#{dist_gz}", "/tmp"
  step "Pre Test Setup -- Untar install package on hosts"
  on host,"cd /tmp && gunzip #{dist_gz} && tar xf #{dist_tar}"
end

# Upgrade Master first
hosts.each do |host|
  next if !( host['roles'].include? 'master' )
  platform       = host['platform']
  dist_dir       = "puppet-enterprise-#{version}-#{platform}"

  step "SCP Master Answer file to dist tar dir"
  scp_to host, "tmp/upgrade_a", "/tmp/#{dist_dir}"
  step "Upgrade Puppet Master"
  on host,"cd /tmp/#{dist_dir} && ./puppet-enterprise-upgrader -a upgrade_a"
end

# Install Puppet Agents
step "Install Puppet Agent"
hosts.each do |host|
  next if host['roles'].include? 'master'
  role_agent=FALSE
  role_dashboard=FALSE
  role_agent=TRUE     if host['roles'].include? 'agent'
  role_dashboard=TRUE if host['roles'].include? 'dashboard'
  platform       = host['platform']
  dist_dir       = "puppet-enterprise-#{version}-#{platform}"

  step "SCP Answer file to dist tar dir"
  scp_to host, "tmp/upgrade_a", "/tmp/#{dist_dir}"
  step "Upgrade Puppet Agent"
  on host,"cd /tmp/#{dist_dir} && ./puppet-enterprise-upgrader -a upgrade_a"
end
