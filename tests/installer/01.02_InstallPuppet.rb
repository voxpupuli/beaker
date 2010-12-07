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
      # Execute for every role per host
      @config["HOSTS"][host]['roles'].each do |role|
        dist_dir="puppet-enterprise-#{version}-rhel-5-x86_64" if   ( /RHEL5-64/ =~ @config["HOSTS"][host]['platform'] )
        dist_dir="puppet-enterprise-#{version}-centos-5-x86_64" if ( /CENT5-64/ =~ @config["HOSTS"][host]['platform'] )

        scper = ScpFile.new(host)
        result = scper.do_scp("#{$work_dir}/tarballs/answers.tar", "/root/#{dist_dir}")
       
        command=""
        if /master/ =~ role then        # If the host is puppet master
          command = "cd #{dist_dir} && tar xf answers.tar && ./puppet-enterprise-installer -a q_master_only.sh"
        elsif /agent/ =~ role then      # If the host is puppet agent
          command = "cd #{dist_dir} && tar xf answers.tar && ./puppet-enterprise-installer -a q_agent_only.sh"
        elsif /dashboard/ =~ role then  # If the host will run dashboard
          command = "cd #{dist_dir} && tar xf answers.tar && ./puppet-enterprise-installer -a q_dashboard_only.sh"
        end
        BeginTest.new(host, test_name)
        runner = RemoteExec.new(host)
        result = runner.do_remote("#{command}")
        @fail_flag+=result.exit_code
        ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)
      end # /role
    end
    # do post install test environment config
    prep_nodes(config)
  end
end
