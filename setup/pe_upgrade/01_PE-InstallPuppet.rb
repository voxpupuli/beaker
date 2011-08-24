# PE upgrader test
version  = options[:upgrade]
test_name "Install Puppet #{version}"
hosts.each do |host|
  platform = host['platform']

  # hack-o-rama:
  # tarballs have changed name rhel- is now el- and affects package naming
  # change el- to rhel- to match the old tarball naming/path
  platform = "rhel-#{$1}" if platform =~ /el-(.*)/

  # determine the distro tar name
  dist_tar = "puppet-enterprise-#{version}-#{platform}.tar"
  unless File.file? "/opt/enterprise/dists/pe#{version}/#{dist_tar}"
    Log.error "PE #{dist_tar} not found, help!"
    Log.error ""
    Log.error "Make sure your configuration file uses the PE version string:"
    Log.error "  eg: rhel-5-x86_64  centos-5-x86_64"
    fail_test "Sorry, PE #{dist_tar} file not found."
  end

  step "Pre Test Setup -- SCP install package to hosts"
  scp_to host, "/opt/enterprise/dists/pe#{version}/#{dist_tar}", "/tmp"
  step "Pre Test Setup -- Untar install package on hosts"
  on host,"cd /tmp && tar xf #{dist_tar}"
end

# Install Master first -- allows for auto cert signing
hosts.each do |host|
  next if !( host['roles'].include? 'master' )
  platform       = host['platform']
  platform = "rhel-#{$1}" if platform =~ /el-(.*)/
  dist_dir       = "puppet-enterprise-#{version}-#{platform}"

  step "SCP Master Answer file to dist tar dir"
  scp_to host, "tmp/answers.#{host}", "/tmp/#{dist_dir}"
  step "Install Puppet Master"
  on host,"cd /tmp/#{dist_dir} && ./puppet-enterprise-installer -a answers.#{host}"
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
  platform = "rhel-#{$1}" if platform =~ /el-(.*)/
  dist_dir       = "puppet-enterprise-#{version}-#{platform}"

  step "SCP Answer file to dist tar dir"
  scp_to host, "tmp/answers.#{host}", "/tmp/#{dist_dir}"
  step "Install Puppet Agent"
  on host,"cd /tmp/#{dist_dir} && ./puppet-enterprise-installer -a answers.#{host}"
end
