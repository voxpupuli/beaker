# Puppet Installer
# Accepts hash of parsed config file as arg
class InstallPuppet
  attr_accessor :config, :fail_flag 
  def initialize(config)
    self.config    = config
    self.fail_flag = 0

    host=""
    role=""
    usr_home=ENV['HOME']
    inst_path="/root/enterprise-dist/installer"
    
    test_name="Install Puppet"
    # Execute for every host
    @config["HOSTS"].each_key do|host|
      # Execute for every role per host
      @config["HOSTS"][host]['roles'].each do |role|
        command=""
        if /master/ =~ role then        # If the host is puppet master
          command = "cd #{inst_path} && ./puppet-enterprise-installer -a q_master_only.sh"
        elsif /agent/ =~ role then      # If the host is puppet agent
          command = "cd #{inst_path} && ./puppet-enterprise-installer -a q_agent_only.sh"
        elsif /dashboard/ =~ role then  # If the host will run dashboard
          command = "cd #{inst_path} && ./puppet-enterprise-installer -a q_dashboard_only.sh"
        end
        BeginTest.new(host, test_name)
        runner = RemoteExec.new(host)
        result = runner.do_remote("#{command}")
        @fail_flag+=result.exit_code
        ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)
      end # /role
    end
  end
end
