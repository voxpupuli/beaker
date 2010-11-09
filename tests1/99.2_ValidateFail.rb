# Validate Failed Test
# Accepts hash of parsed config file as arg
class ValidateFail
  attr_accessor :config, :fail_flag 
  def initialize(config)
    self.config    = config
    self.fail_flag = 0

    host=""
    os=""
    test_name="Validate Failed Test"
    usr_home=ENV['HOME']
    binpath="/opt/puppet/bin"

    # Execute validater on each node
    @config.host_list.each do |host, os|
      if /^PMASTER/ =~ os then         # Detect Puppet Master node
        BeginTest.new(host, test_name)
        runner = RemoteExec.new(host)
        result = runner.do_remote("foo_command")
        @fail_flag+=result.exit_code
        ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)
      elsif /^AGENT/ =~ os then        # Detect Puppet Agent node
        BeginTest.new(host, test_name)
        runner = RemoteExec.new(host)
        result = runner.do_remote("foo_command")
        @fail_flag+=result.exit_code
        ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)
      end
    end
  end
end
