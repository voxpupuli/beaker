# Pre Test Setup stage
# SCP installer to host
# Untar Installer
# Accepts hash of parsed config file as arg
class TestSetup
  attr_accessor :config, :fail_flag 
  def initialize(config)
    self.config    = config
    self.fail_flag = 0

    host=""
    usr_home=ENV['HOME']

    test_name="Pre Test Setup -- SCP installer to hosts"
    # SCP install file to each host
    @config["HOSTS"].each_key do|host|
      BeginTest.new(host, test_name)
      scper = ScpFile.new(host)
      result = scper.do_scp("#{usr_home}/install.tgz", "/root/install.tgz")
      @fail_flag+=result.exit_code
      ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)
    end

    test_name="Pre Test Setup -- Untar installer on hosts"
    # Untar install packges on each host
    @config["HOSTS"].each_key do|host|
      BeginTest.new(host, test_name)
      runner = RemoteExec.new(host)
      result = runner.do_remote("tar xzf install.tgz")
      @fail_flag+=result.exit_code
      ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)
    end
  end
end
