# Validate Install
# Accepts hash of parsed config file as arg
class ValidateVersion
  attr_accessor :config, :fail_flag 
  def initialize(config)
    self.config    = config
    self.fail_flag = 0

    host=""
    os=""
    test_name="Validate Puppet Version"
    usr_home=ENV['HOME']

    # Execute validater on each node
    @config.host_list.each do |host, os|
      if /^PMASTER/ =~ os then         # Detect Puppet Master node
        BeginTest.new(host, test_name)
        runner = RemoteExec.new(host)
        result = runner.do_remote("/usr/bin/puppet --version")
        p result.output
        @fail_flag+=result.exit_code
        ChkResult.new(host, test_name, result.exit_code, result.output)
      elsif /^AGENT/ =~ os then        # Detect Puppet Agent node
        BeginTest.new(host, test_name)
        runner = RemoteExec.new(host)
        result = runner.do_remote("/usr/bin/puppet --version")
        p result.output
        @fail_flag+=result.exit_code
        ChkResult.new(host, test_name, result.exit_code, result.output)
      end
    end
  end
end
