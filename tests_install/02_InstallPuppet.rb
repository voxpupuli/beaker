# Puppet Installer
# Accepts hash of parsed config file as arg
class InstallPuppet
  attr_accessor :config, :fail_flag 
  def initialize(config)
    self.config    = config
    self.fail_flag = 0

    host=""
    role=""
    inst_path="/root/enterprise-dist/installer"
    usr_home=ENV['HOME']
    
    test_name="Install Puppet"
    # Execute install on each host
    @config.each_key do|host|
      @config[host]['roles'].each do|role|
        if /master/ =~ role then             # If the host is puppet master
          BeginTest.new(host, test_name)
          runner = RemoteExec.new(host)
          result = runner.do_remote("cd #{inst_path} && ./puppet-enterprise-installer -a q_master_only.sh")
          @fail_flag+=result.exit_code
          ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)
        elsif /agent/ =~ role then           # If the host is puppet agent
          BeginTest.new(host, test_name)
          runner = RemoteExec.new(host)
          result = runner.do_remote("cd #{inst_path} && ./puppet-enterprise-installer -a q_agent_only.sh")
          @fail_flag+=result.exit_code
          ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)
        elsif /dashboard/ =~ role then       # If the host will run dashboard
          BeginTest.new(host, test_name)
          runner = RemoteExec.new(host)
          result = runner.do_remote("cd #{inst_path} && ./puppet-enterprise-installer -a q_dashboard_only.sh")
          @fail_flag+=result.exit_code
          ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)
        end
      end
    end
  end
end
