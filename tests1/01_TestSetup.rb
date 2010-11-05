# Pre Test Setup stage
# Accepts hash of parsed config file as arg
class TestSetup
  attr_accessor :config, :fail_flag 
  def initialize(config)
    self.config    = config
    self.fail_flag = 0

    host=""
    os=""
    test_name="Pre Test Setup"
    usr_home=ENV['HOME']

    # SCP install file to each host
    @config.host_list.each do |host, os|
      if /^PMASTER/ =~ os then         # Detect Puppet Master node
        BeginTest.new(host, test_name)
        scper = ScpFile.new(host)
        result = scper.do_scp("#{usr_home}/install.tgz", "/root/install.tgz")
        @fail_flag+=result.exit_code
        ChkResult.new(host, test_name, result.exit_code, result.output)
      elsif /^AGENT/ =~ os then        # Detect Puppet Agent node
        BeginTest.new(host, test_name)
        scper = ScpFile.new(host)
        result = scper.do_scp("#{usr_home}/install.tgz", "/root/install.tgz")
        @fail_flag+=result.exit_code
        ChkResult.new(host, test_name, result.exit_code, result.output)
      end
    end
  end
end
