# PE upgrader test
version  = config['pe_ver']
upgrade_v = options[:upgrade]

if options[:pe_version]
  distpath = "#{config['pe_dir']}/pe#{version}"
else
  distpath = "#{config['pe_dir']}"
end

def is_http(path)
  path =~ /^https?:\/\/.+/
end

test_name "Upgrade #{upgrade_v} to #{version}"
hosts.each do |host|
  platform = host['platform']

  step "Pre Test Setup -- clean up /tmp"
  on host,"rm -f /tmp/*.tar ; rm -f /tmp/*.gz", :acceptable_exit_codes => (0..255)

  host['dist'] = "puppet-enterprise-#{version}-#{platform}"

  step "Pre Test Setup -- copy install package to hosts"
  if is_http "#{distpath}"
    on host, "curl #{distpath}/#{host['dist']}.tar.gz -o /tmp/#{host['dist']}.tar.gz"
  else
    unless File.file? "#{distpath}/#{host['dist']}.tar.gz"
      logger.error "PE #{host['dist']}.tar.gz not found, help!"
      logger.error ""
      logger.error "Make sure your configuration file uses the PE version string:"
      logger.error "  eg: rhel-5-x86_64  centos-5-x86_64"
      fail_test "Sorry, PE #{host['dist']}.tar.gz file not found."
    end
    scp_to host, "#{distpath}/#{host['dist']}.tar.gz", "/tmp"
  end  
  step "Pre Test Setup -- Untar install package on hosts"
  on host,"cd /tmp && gunzip #{host['dist']}.tar.gz && tar xf #{host['dist']}.tar"
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
