# Pre Test Setup stage
# SCP installer to host, Untar Installer
#
version  = config['pe_ver']
hosts.each do |host|
  platform = host['platform']

  # determine the distro tar name
  dist_tar = "puppet-enterprise-#{version}-#{platform}.tar"
  unless File.file? "/opt/enterprise/dists/#{dist_tar}"
    Log.error "PE #{dist_tar} not found, help!"
    Log.error ""
    Log.error "Make sure your configuration file uses the PE version string:"
    Log.error "  eg: rhel-5-x86_64  centos-5-x86_64"
    fail_test "Sorry, PE #{dist_tar} file not found."
  end

  step "Pre Test Setup -- SCP install package to hosts"
  scp_to host, "/opt/enterprise/dists/#{dist_tar}", "/tmp"
  step "Pre Test Setup -- Untar install package on hosts"
  on host,"cd /tmp && tar xf #{dist_tar}"

end

# Install Master first -- allows for auto cert signing
hosts.each do |host|
  next if !( host['roles'].include? 'master' )
  platform       = host['platform']
  dist_dir       = "puppet-enterprise-#{version}-#{platform}"

  step "SCP Master Answer file to dist tar dir"
  scp_to host, "tmp/q_master_only", "/tmp/#{dist_dir}"
  step "Install Puppet Master"
  on host,"cd /tmp/#{dist_dir} && ./puppet-enterprise-installer -a q_master_only"
end

# Install Puppet Agents
step "Install Puppet Agent"
hosts.each do |host|
  next if !( host['roles'].include? 'agent' )
  role_agent     = host['roles'].include? 'agent'
  role_dashboard = host['roles'].include? 'dashboard'
  platform       = host['platform']
  dist_dir       = "puppet-enterprise-#{version}-#{platform}"

  q_script = case
    when (role_agent  && !role_dashboard); "q_agent_only"
    when (role_agent  && role_dashboard);  "q_agent_and_dashboard"
    when (!role_agent && role_dashboard);  "q_dashboard_only"
    else Log.debug "Agent warn #{host} has an unacceptable combination of roles."
  end

  step "SCP Answer file to dist tar dir"
  scp_to host, "tmp/#{q_script}", "/tmp/#{dist_dir}"
  step "Install Puppet Agent"
  on host,"cd /tmp/#{dist_dir} && ./puppet-enterprise-installer -a #{q_script}"
end
