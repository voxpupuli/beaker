# Validate Puppet Install
# Accepts hash of parsed config file as arg
class ValidatePuppet
  attr_accessor :config, :fail_flag 
  def initialize(config)
    self.config    = config
    self.fail_flag = 0

    host=""
    usr_home=ENV['HOME']
    binpath="/opt/puppet/bin"

    test_name="Validate Ruby Install"
    # Validate correct puppet bin path on each host
    @config["HOSTS"].each_key do|host|
      BeginTest.new(host, test_name)
      runner = RemoteExec.new(host)
      result = runner.do_remote("#{binpath}/puppet --version")
      @fail_flag+=result.exit_code
      result.log(test_name)
    end
  end
end
