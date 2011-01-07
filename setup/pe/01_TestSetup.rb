# Pre Test Setup stage
# SCP installer to host, Untar Installer

test_name "Install puppet and facter on target machines..."

hosts.each do |host|
  version  = host["puppetver"]
  dist_dir = "puppet-enterprise-#{version}-#{host['platform']}"
  dist_tar = "puppet-enterprise-#{version}-#{host['platform']}.tar"

  unless File.file? dist_tar
    puts "PE #{dist_tar} not found, help!"
    puts ""
    puts "Make sure your configuration file uses the PE version string:"
    puts "  eg: rhel-5-x86_64  centos-5-x86_64"
    fail_test "Sorry, PE #{dist_tar} file not found."
  end

  step "Pre Test Setup -- SCP install package to hosts"
  scp_to host, "#{$work_dir}/tarballs/#{dist_tar}", "/root"
  scp_to host, "#{$work_dir}/tarballs/answers.tar", "/root"

  step "Pre Test Setup -- Untar install package on hosts"
  on host,"tar xf #{dist_tar}"

  step "Pre Test Setup -- Install the installer answers"
  version        = host["puppetver"]
  role_agent     = host['roles'].include? 'agent'
  role_master    = host['roles'].include? 'master'
  role_dashboard = host['roles'].include? 'dashboard'

  q_script = case
             when (role_agent  && !role_dashboard); "q_agent_only.sh"
             when (role_master && !role_dashboard); "q_master_only.sh"
             when (role_master &&  role_dashboard); "q_master_and_dashboard.sh"
             else fail "#{host} has an unacceptable combination of roles."
             end

  step "Pre Test Setup -- Run the Installer"
  on host,"cd #{dist_dir} && tar xf /root/answers.tar -C . && ./puppet-enterprise-installer -a #{q_script}"
end
