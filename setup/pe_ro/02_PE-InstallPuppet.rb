# Puppet Installer
# Run installer w/answer files

version  = config['pe_ver']

# Determine NFS mount from config
nfs_mnt = config['pe_nfs_mount']

step "NFS RO Install Puppet Master"
hosts.each do |host|
  next if !( host['roles'].include? 'master' )
  role_dashboard = host['roles'].include? 'dashboard'
  platform       = host['platform']
  dist_dir       = "#{nfs_mnt}/puppet-enterprise-#{version}-#{platform}"

  q_script = case
    when (!role_dashboard); "q_master_only"
    when (role_dashboard);  "q_master_and_dashboard"
    else logger.debug "Master warn #{host} has an unacceptable combination of roles."
  end
  on host,"cd #{dist_dir} && ./puppet-enterprise-installer -a /#{nfs_mnt}/#{q_script}"
end

# Install Puppet Agents
step "NFS RO Install Puppet Agent"
hosts.each do |host|
  next if host['roles'].include? 'master'
  role_agent     = host['roles'].include? 'agent'
  role_dashboard = host['roles'].include? 'dashboard'
  platform       = host['platform']

  # determine the distro dir - on the NFS server
  dist_dir = "#{nfs_mnt}/puppet-enterprise-#{version}-#{platform}"

  q_script = case
    when (role_agent  && !role_dashboard); "q_agent_only"
    when (role_agent  && role_dashboard);  "q_agent_and_dashboard"
    when (!role_agent && role_dashboard);  "q_dashboard_only"
    else logger.debug "Agent warn #{host} has an unacceptable combination of roles."
  end
  on host,"cd #{dist_dir} && ./puppet-enterprise-installer -a /#{nfs_mnt}/#{q_script}"
end
