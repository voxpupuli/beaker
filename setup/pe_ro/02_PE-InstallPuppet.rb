# Puppet Installer
# Run installer w/answer files

# Determine NFS mount from config
nfs_mnt = config['pe_nfs_mount']

step "NFS RO Install Puppet Master"
hosts.each do |host|
  next if host['roles'].include? 'agent'
  role_master    = host['roles'].include? 'master'
  role_dashboard = host['roles'].include? 'dashboard'
  version        = host["puppetver"]
  platform       = host['platform']

  # determine the distro dir - on the NFS server
  dist_dir = "#{nfs_mnt}/puppet-enterprise-#{version}-#{platform}"

  q_script = case
    when (role_master && !role_dashboard); "q_master_only"
    when (role_master &&  role_dashboard); "q_master_and_dashboard"
    else fail "#{host} has an unacceptable combination of roles."
  end
  on host,"cd #{dist_dir} && ./puppet-enterprise-installer -a /#{nfs_mnt}/#{q_script}"
end


step "NFS RO Install Puppet Agent"
hosts.each do |host|
  next if host['roles'].include? 'master'
  role_agent     = host['roles'].include? 'agent'
  role_dashboard = host['roles'].include? 'dashboard'
  version        = host["puppetver"]
  platform       = host['platform']

  # determine the distro dir - on the NFS server
  dist_dir = "#{nfs_mnt}/puppet-enterprise-#{version}-#{platform}"

  q_script = case
    when (role_agent  && !role_dashboard); "q_agent_only"
    when (role_master && !role_dashboard); "q_master_only"
    else fail "#{host} has an unacceptable combination of roles."
  end
  on host,"cd #{dist_dir} && ./puppet-enterprise-installer -a /#{nfs_mnt}/#{q_script}"
end
