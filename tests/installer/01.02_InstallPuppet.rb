# Puppet Installer
# Run installer w/answer files
# Accepts hash of parsed config file as arg
class InstallPuppet
  attr_accessor :config, :fail_flag 
  def initialize(config)
    self.config    = config
    self.fail_flag = 0

    host=""
    dist_dir=""
    version=config["CONFIG"]["puppetver"]

    test_name="Install Puppet"
    # Execute for every host
    @config["HOSTS"].each_key do|host|
      role_agent=FALSE
      role_master=FALSE
      role_dashboard=FALSE

      # What platform is this host?
      dist_dir="puppet-enterprise-#{version}-rhel-5-x86_64" if   ( /RHEL5-64/ =~ @config["HOSTS"][host]['platform'] )
      dist_dir="puppet-enterprise-#{version}-centos-5-x86_64" if ( /CENT5-64/ =~ @config["HOSTS"][host]['platform'] )

      # What role(s) does this node serve?
      config["HOSTS"][host]['roles'].each do |role|
        role_agent=TRUE if role =~ /agent/
        role_master=TRUE if role =~ /master/
        role_dashboard=TRUE if role =~ /dashboard/
      end 

      command=""
      # Host is only an Agent
      if role_agent && !role_dashboard then
        command = "cd #{dist_dir} && tar xf /root/answers.tar -C . && ./puppet-enterprise-installer -a q_agent_only.sh"
      end

      # Host is a Master only - no Dashbord
      if role_master && !role_dashboard then
        command = "cd #{dist_dir} && tar xf /root/answers.tar -C . && ./puppet-enterprise-installer -a q_master_only.sh"
      end

      # Host is a Master and Dashboard
      if role_master && role_dashboard then
        command = "cd #{dist_dir} && tar xf /root/answers.tar -C . && ./puppet-enterprise-installer -a q_master_and_dashboard.sh"
      end
       
      BeginTest.new(host, test_name)
      runner = RemoteExec.new(host)
      result = runner.do_remote("#{command}")
      @fail_flag+=result.exit_code
      ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)

    end # end HOST block
    # do post install test environment config
    prep_nodes(config)
  end
end
