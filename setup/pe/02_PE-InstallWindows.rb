# SCP windows msi to host and install

version  = config['pe_ver_win']
test_name "Install Puppet #{version}"

confine :to, :platform => 'windows'
distpath = "/opt/enterprise/dists"

Log.warn "Install PE Windows version #{version}"
hosts.each do |host|
  host['dist'] = "puppet-enterprise-#{version}"

  # determine the distro tar name
  unless File.file? "#{distpath}/#{host['dist']}.msi"
    Log.error "PE #{host['dist']}.msi not found, help!"
    Log.error ""
    # Log.error "Make sure your configuration file uses the PE version string:"
    # Log.error "  eg: rhel-5-x86_64  centos-5-x86_64"
    fail_test "Sorry, PE #{host['dist']}.msi file not found."
  end

  step "Pre Test Setup -- SCP install package to hosts"
  scp_to host, "#{distpath}/#{host['dist']}.msi", "/tmp"

  step "Install Puppet Agent"
  on host,"cd /tmp && msiexec.exe /qn /i #{host['dist']}.msi"
end
