# Validate Positive Test
# Accepts hash of parsed config file as arg
class ValidatePass
  attr_accessor :config, :fail_flag 
  def initialize(config)
    self.config    = config
    self.fail_flag = 0

    host=""
    role=""
    usr_home=ENV['HOME']

    test_name="Validate Positive Test"
    # Execute remote command  on each node, regardless of role
    @config.each_key do|host|
      runner = RemoteExec.new(host)
      result = runner.do_remote("uname -a")
      @fail_flag+=result.exit_code
      ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)
    end
  end
end
