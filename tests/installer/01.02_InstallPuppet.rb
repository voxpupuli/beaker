# Puppet Installer
# Run installer w/answer files


step "Install Puppet"

hosts.each do |host|
  version        = host["puppetver"]
  role_agent     = host['roles'].include? 'agent'
  role_master    = host['roles'].include? 'master'
  role_dashboard = host['roles'].include? 'dashboard'

  # What platform is this host?
  dist_dir="puppet-enterprise-#{version}-rhel-5-x86_64"   if /RHEL5-64/ =~ host['platform']
  dist_dir="puppet-enterprise-#{version}-centos-5-x86_64" if /CENT5-64/ =~ host['platform']

  q_script = case
    when (role_agent  && !role_dashboard); "q_agent_only.sh"
    when (role_master && !role_dashboard); "q_master_only.sh"
    when (role_master &&  role_dashboard); "q_master_and_dashboard.sh"
    else fail "#{host} has an unacceptable combination of roles."
    end
  on host,"cd #{dist_dir} && tar xf /root/answers.tar -C . && ./puppet-enterprise-installer -a #{q_script}"
end

# do post install test environment config
prep_nodes
