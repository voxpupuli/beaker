# Validate Facter Install
# Accepts hash of parsed config file as arg
class ValidateFacter
  attr_accessor :config, :fail_flag 
  def initialize(config)
    self.config    = config
    self.fail_flag = 0

    host=""
    usr_home=ENV['HOME']
    binpath="/opt/puppet/bin"

    test_name="Validate Facter Install"
    # Validate correct facter bin path on each host
    @config["HOSTS"].each_key do|host|
      BeginTest.new(host, test_name)
      runner = RemoteExec.new(host)
      result = runner.do_remote("#{binpath}/facter --version")
      @fail_flag+=result.exit_code
      ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)
    end
  end
end
