# Test Validate Install
# Accepts hash of parsed config file as arg
class ValidateInstall_NN          # Name the class something meaninful, NN=number
  attr_accessor :config, :exit_code
  def initialize(config)
    self.config    = config		    #	
    self.exit_code = exit_code    #

    host=""
    os=""
    test_name="Meaningful description of the test"
    usr_home=ENV['HOME']
    fail_flag=0

    # Execute test on each node -- diff behaviours possible depending role
    @config.host_list.each do |host, os|
      if /^PMASTER/ =~ os then         # Detect Puppet Master node
        puts "Validating install on #{host}"
        runner = RemoteExec.new(host)
        result = runner.do_remote("command or remote script to run")
        p result.output
        ChkResult.new(host, test_name, result.exit_code)
        @exit_code=result.exit_code
      elsif /^AGENT/ =~ os then        # Detect Puppet Agent node
        puts "Validating install on #{host}"
        runner = RemoteExec.new(host)
        result = runner.do_remote("command or remote script to run")
        p result.output
        @exit_code=result.exit_code
        ChkResult.new(host, test_name, result.exit_code)
      end
    end
  end
end
