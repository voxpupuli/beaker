# Pre Test Setup stage
# SCP installer to host, Untar Installer
hosts.each do |host|
  step "Pre Test Setup -- SCP install package to hosts"
  version  = host["puppetver"]
  platform = host['platform']

  # determine the distro dir
  dist_tar = "puppet-enterprise-#{version}-#{platform}.tar"
  unless File.file? dist_tar
    puts "PE #{dist_tar} not found, help!"
    puts ""
    puts "Make sure your configuration file uses the PE version string:"
    puts "  eg: rhel-5-x86_64  centos-5-x86_64"
    fail_test "Sorry, PE #{dist_tar} file not found."
  end

  scp_to host, "#{$work_dir}/tarballs/#{dist_tar}", "/root"
  scp_to host, "#{$work_dir}/tarballs/answers.tar", "/root"

  step "Pre Test Setup -- Untar install package on hosts"
  on host,"tar xf #{dist_tar}"
end

# Puppet Installer
# Install Master first -- allows for auto cert signing
step "Install Puppet Master"
hosts.each do |host|
  next if host['roles'].include? 'agent'
  role_master    = host['roles'].include? 'master'
  role_dashboard = host['roles'].include? 'dashboard'
  version        = host["puppetver"]
  platform       = host['platform']

  # determine the distro dir
  dist_dir = "puppet-enterprise-#{version}-#{platform}"

  q_script = case
    when (role_master && !role_dashboard); "q_master_only.sh"
    when (role_master &&  role_dashboard); "q_master_and_dashboard.sh"
    else fail "#{host} has an unacceptable combination of roles."
  end
  on host,"cd #{dist_dir} && tar xf /root/answers.tar -C . && ./puppet-enterprise-installer -a #{q_script}"
end


# Install Puppet Agents
step "Install Puppet Agent"
hosts.each do |host|
  next if host['roles'].include? 'master'
  role_agent     = host['roles'].include? 'agent'
  role_dashboard = host['roles'].include? 'dashboard'
  version        = host["puppetver"]
  platform       = host['platform']

  # determine the distro dir
  dist_dir = "puppet-enterprise-#{version}-#{platform}"

  q_script = case
    when (role_agent  && !role_dashboard); "q_agent_only.sh"
    when (role_master && !role_dashboard); "q_master_only.sh"
    else fail "#{host} has an unacceptable combination of roles."
  end
  on host,"cd #{dist_dir} && tar xf /root/answers.tar -C . && ./puppet-enterprise-installer -a #{q_script}"
end

# do post install test environment config
# prep_nodes
