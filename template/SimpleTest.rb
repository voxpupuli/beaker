# Test Template
# Very simple test case
class SimpleTest
  attr_accessor :config, :fail_flag 
  def initialize(config)
    self.config    = config
    self.fail_flag = 0

    host=""
    os=""
    usr_home=ENV['HOME']

    test_name="Perform same action on each host"
    # SCP install file to each host
    @config.each_key do|host|
      BeginTest.new(host, test_name)
      runner = RemoteExec.new(host)
      result = runner.do_remote("uname")
      @fail_flag+=result.exit_code
      ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)
    end

    test_name="Perform specific action based on host's role"
    # Parse for 'role' and take action accordingly
    @config.each_key do|host|
      @config[host]['roles'].each do|role|
        if /master/ =~ role then             # The host is puppet master
          BeginTest.new(host, test_name)
          runner = RemoteExec.new(host)
          result = runner.do_remote("puppet master specific command")
          @fail_flag+=result.exit_code
          ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)
        elsif /agent/ =~ role then           # The host is puppet agent
          BeginTest.new(host, test_name)
          runner = RemoteExec.new(host)
          result = runner.do_remote("puppet agent specific command")
          @fail_flag+=result.exit_code
          ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)
        elsif /dashboard/ =~ role then       # If the host will run dashboard
          BeginTest.new(host, test_name)
          runner = RemoteExec.new(host)
          result = runner.do_remote("puppet dashboard specific command")
          @fail_flag+=result.exit_code
          ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)
        end
      end
    end

  end
end
