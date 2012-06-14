# PE upgrader test
#version  = options[:upgrade]
#test_name "Install Puppet #{version}"
#hosts.each do |host|
#  platform = host['platform']
#
#  # hack-o-rama: this is likely to be fragile and very PE 1.0, 1.1 specifc:
#  # Tarballs have changed name rhel- is now el- and affects package naming
#  # change el- to rhel- to match the old tarball naming/paths.
#  # It gets worse, of course, as Centos differs from RHEL as well
#  unless version =~ /^1\.2/
#    if platform =~ /el-(.*)/ and host.name.include? 'cent'
#      platform = "centos-#{$1}" 
#    elsif platform =~ /el-(.*)/ and host.name.include? 'rhel'
#      platform = "rhel-#{$1}" 
#    end
#  end
#  host['dist'] = "puppet-enterprise-#{version}-#{platform}"
#  long_name = Dir.glob("/opt/enterprise/dists/pe#{version}/*")[0]
#  basename = File.basename(long_name)
#  ext = basename.match(/tar.*/).to_s
#
#  unless File.file? "/opt/enterprise/dists/pe#{version}/#{host['dist']}.#{ext}"
#    logger.error "PE #{host['dist']}.#{ext} not found, help!"
#    logger.error ""
#    logger.error "Make sure your configuration file uses the PE version string:"
#    logger.error "  eg: rhel-5-x86_64  centos-5-x86_64"
#    fail_test "Sorry, PE #{host['dist']}.#{ext} file not found."
#  end
#
#  step "Pre Test Setup -- SCP install package to hosts"
#  scp_to host, "/opt/enterprise/dists/pe#{version}/#{host['dist']}.#{ext}", "/tmp"
#  step "Pre Test Setup -- Untar install package on hosts"
#  on host,"cd /tmp && tar xf #{host['dist']}.#{ext}"
#end
#
## Install Master first -- allows for auto cert signing
#hosts.each do |host|
#  next if !( host['roles'].include? 'master' )
#  step "SCP Master Answer file to #{host} #{host['dist']}"
#  scp_to host, "tmp/answers.#{host}", "/tmp/#{host['dist']}"
#  step "Install Puppet Master"
#  on host,"cd /tmp/#{host['dist']} && ./puppet-enterprise-installer -a answers.#{host}"
#end
#
## Install Puppet Agents
#step "Install Puppet Agent"
#hosts.each do |host|
#  next if host['roles'].include? 'master'
#  role_agent=FALSE
#  role_dashboard=FALSE
#  role_agent=TRUE     if host['roles'].include? 'agent'
#  role_dashboard=TRUE if host['roles'].include? 'dashboard'
#
#  step "SCP Answer file to dist tar dir"
#  scp_to host, "tmp/answers.#{host}", "/tmp/#{host['dist']}"
#  step "Install Puppet Agent"
#  on host,"cd /tmp/#{host['dist']} && ./puppet-enterprise-installer -a answers.#{host}"
#end
