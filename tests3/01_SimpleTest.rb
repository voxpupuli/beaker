# Test Template
# Very simple test case
class SimpleTest
  attr_accessor :config, :fail_flag 
  def initialize(config)
    self.config    = config
    self.fail_flag = 0

    host=""
    os=""
    test_name="File Test"
    usr_home=ENV['HOME']

    # Check config for nodes
    @config.host_list.each do |host, os|
      if /^AGENT/ =~ os then        # Detect Puppet Agent node
        BeginTest.new(host, test_name) # might require different actions on Agent
        runner = RemoteExec.new(host)
        result = runner.do_remote("/root/remote_exec/file_checks.sh")
        @fail_flag+=result.exit_code  # Add exit_code to fail_flag
        ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)
      end
    end
  end
end
