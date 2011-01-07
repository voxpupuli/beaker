# Pre Test Setup stage
# SCP installer to host, Untar Installer

test_name "Install puppet and facter on target machines..."

hosts.each do |host|
  step "Pre Test Setup -- SCP install package to hosts"
  version = host["puppetver"]
  dist_tar = case host['platform']
             when /RHEL5-64/; "puppet-enterprise-#{version}-rhel-5-x86_64.tar"
             when /CENT5-64/; "puppet-enterprise-#{version}-centos-5-x86_64.tar"
             else fail "Unknown platform: #{host['platform']}"
             end
  scp_to host, "#{$work_dir}/tarballs/#{dist_tar}", "/root"
  scp_to host, "#{$work_dir}/tarballs/answers.tar", "/root"

  step "Pre Test Setup -- Untar install package on hosts"
  on host,"tar xf #{dist_tar}"

  version        = host["puppetver"]
  role_agent     = host['roles'].include? 'agent'
  role_master    = host['roles'].include? 'master'
  role_dashboard = host['roles'].include? 'dashboard'

  # What platform is this host?
  dist_dir = case host['platform']
             when 'RHEL5-64' then "puppet-enterprise-#{version}-rhel-5-x86_64"
             when 'CENT5-64' then "puppet-enterprise-#{version}-centos-5-x86_64"
             else fail_test "unable to determine the platform " +
                 "PE version for #{host['platform']}"
             end

  q_script = case
             when (role_agent  && !role_dashboard); "q_agent_only.sh"
             when (role_master && !role_dashboard); "q_master_only.sh"
             when (role_master &&  role_dashboard); "q_master_and_dashboard.sh"
             else fail "#{host} has an unacceptable combination of roles."
             end
  on host,"cd #{dist_dir} && tar xf /root/answers.tar -C . && ./puppet-enterprise-installer -a #{q_script}"
end
