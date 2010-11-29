# Validate Failed Test
# Accepts hash of parsed config file as arg
class ValidateFail
  attr_accessor :config, :fail_flag 
  def initialize(config)
    self.config    = config
    self.fail_flag = 0

    host=""
    role=""
    usr_home=ENV['HOME']

    test_name="Validate Failed Test"
    # Execute remote command  on each node, regardless of role
    @config["HOSTS"].each_key do|host|
      BeginTest.new(host, test_name)
      runner = RemoteExec.new(host)
      result = runner.do_remote("foo command")
      @fail_flag+=result.exit_code
      ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)
    end
  end
end

