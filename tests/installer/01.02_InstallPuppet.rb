# Puppet Installer
# Run installer w/answer files

version=config["CONFIG"]["puppetver"]

test_name="Install Puppet"

hosts.each do |host|
  role_agent=false
  role_master=false
  role_dashboard=false

  # What platform is this host?
  dist_dir="puppet-enterprise-#{version}-rhel-5-x86_64" if   ( /RHEL5-64/ =~ @config["HOSTS"][host]['platform'] )
  dist_dir="puppet-enterprise-#{version}-centos-5-x86_64" if ( /CENT5-64/ =~ @config["HOSTS"][host]['platform'] )

  # What role(s) does this node serve?
  config["HOSTS"][host]['roles'].each do |role|
    role_agent=TRUE if role =~ /agent/
    role_master=TRUE if role =~ /master/
    role_dashboard=TRUE if role =~ /dashboard/
  end 

  q_script = case
    when (role_agent  && !role_dashboard); "q_agent_only.sh"
    when (role_master && !role_dashboard); "q_master_only.sh"
    when (role_master &&  role_dashboard); "q_master_and_dashboard.sh"
    else fail "#{host} has an unacceptable combination of roles."
    end
  command = "cd #{dist_dir} && tar xf /root/answers.tar -C . && ./puppet-enterprise-installer -a #{q_script}"
       
  BeginTest.new(host, test_name)
  runner = RemoteExec.new(host)
  result = runner.do_remote("#{command}")
  @fail_flag+=result.exit_code
  result.log(test_name)
end

# do post install test environment config
prep_nodes(config)
