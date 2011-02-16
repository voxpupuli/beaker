# Pre Test Setup stage
# SCP installer to host, Untar Installer
hosts.each do |host|
  version  = host["puppetver"]
  platform = host['platform']

  # determine the distro tar name
  dist_tar = "puppet-enterprise-#{version}-#{platform}.tar"
  unless File.file? "#{$work_dir}/tarballs/#{dist_tar}"
    Log.error "PE #{dist_tar} not found, help!"
    Log.error ""
    Log.error "Make sure your configuration file uses the PE version string:"
    Log.error "  eg: rhel-5-x86_64  centos-5-x86_64"
    fail_test "Sorry, PE #{dist_tar} file not found."
  end

  step "Pre Test Setup -- SCP install package to hosts"
  scp_to host, "#{$work_dir}/tarballs/#{dist_tar}", "/root"
  step "Pre Test Setup -- Untar install package on hosts"
  on host,"tar xf #{dist_tar}"

end

# Install Dashboard only
#hosts.each do |host|
#  next if host['roles'].include? 'agent'
#  next if host['roles'].include? 'master'
#  role_dashboard = host['roles'].include? 'dashboard'
#  version        = host["puppetver"]
#  platform       = host['platform']
#  dist_dir       = "puppet-enterprise-#{version}-#{platform}"
#  q_script       = "q_dashboard_only"
#
#  step "SCP Dashboard answer file to dist tar dir"
#  scp_to host, "#{$work_dir}/tarballs/#{q_script}", "/root/#{dist_dir}"
#  step "Install Puppet Dashboard"
#  on host,"cd #{dist_dir} && ./puppet-enterprise-installer -a #{q_script}"
#end

# Install Master first -- allows for auto cert signing
hosts.each do |host|
  next if !( host['roles'].include? 'master' )
  role_dashboard = host['roles'].include? 'dashboard'
  version        = host["puppetver"]
  platform       = host['platform']
  dist_dir       = "puppet-enterprise-#{version}-#{platform}"

  q_script = case
    when (!role_dashboard); "q_master_only"
    when (role_dashboard); "q_master_and_dashboard"
    else puts "Master warn #{host} has an unacceptable combination of roles."
  end

  step "SCP Master Answer file to dist tar dir"
  scp_to host, "#{$work_dir}/tarballs/#{q_script}", "/root/#{dist_dir}"
  step "Install Puppet Master"
  on host,"cd #{dist_dir} && ./puppet-enterprise-installer -a #{q_script}"
end

# Install Puppet Agents
step "Install Puppet Agent"
hosts.each do |host|
  next if host['roles'].include? 'master'
  role_agent     = host['roles'].include? 'agent'
  role_dashboard = host['roles'].include? 'dashboard'
  version        = host["puppetver"]
  platform       = host['platform']
  dist_dir       = "puppet-enterprise-#{version}-#{platform}"

  q_script = case
    when (role_agent  && !role_dashboard); "q_agent_only"
    when (role_agent  && role_dashboard);  "q_agent_and_dashboard"
    when (!role_agent && role_dashboard);  "q_dashboard_only"
    else puts "Agent warn #{host} has an unacceptable combination of roles."
  end

  step "SCP non-Master Answer file to dist tar dir"
  scp_to host, "#{$work_dir}/tarballs/#{q_script}", "/root/#{dist_dir}"
  step "Install Puppet Agent"
  on host,"cd #{dist_dir} && ./puppet-enterprise-installer -a #{q_script}"
end
