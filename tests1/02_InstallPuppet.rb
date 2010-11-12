# Puppet Installer
# Accepts hash of parsed config file as arg
class InstallPuppet
  attr_accessor :config, :fail_flag 
  def initialize(config)
    self.config    = config
    self.fail_flag = 0

    host=""
    os=""
    inst_path="/root/enterprise-dist/installer"
    test_name="Install Puppet"
    usr_home=ENV['HOME']
    
    # Execute install on each host
    @config.host_list.each do |host, os|
      if /^PMASTER/ =~ os then         # Detect Puppet Master node
        BeginTest.new(host, test_name)
        runner = RemoteExec.new(host)
        result = runner.do_remote("env q_puppetmaster_certname=`hostname` #{inst_path}/puppet-enterprise-installer -a #{inst_path}/q_master_dashboard.sh")
        @fail_flag+=result.exit_code
        ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)
      elsif /^AGENT/ =~ os then        # Detect Puppet Agent node
        BeginTest.new(host, test_name)
        runner = RemoteExec.new(host)
        result = runner.do_remote("env q_puppetclient_certname=`hostname` #{inst_path}/puppet-enterprise-installer -a #{inst_path}/q_agent_only.sh")
        @fail_flag+=result.exit_code
        ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)
      end
    end
  end
end
