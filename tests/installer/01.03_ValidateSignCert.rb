# Validate Cert Signing
class ValidateSignCert
  attr_accessor :config, :fail_flag 
  def initialize(config)
    self.config    = config
    self.fail_flag = 0

    host=""
    master=""
    agent_list=""

    # Parse config for Master and Agents
    test_name="Validate Sign Cert"
    @config["HOSTS"].each_key do|host|
      @config["HOSTS"][host]['roles'].each do |role|
        if /agent/ =~ role then               # If the host is puppet agent
          agent_list = host + " " + agent_list
        end
        if /master/ =~ role then         # Detect Puppet Master node
          master = host
        end
      end
    end

    # This step should not be req'd for PE edition -- agents req certs during install
    # AGENT(s) intiate Cert Signing with PMASTER
    #@config["HOSTS"].each_key do|host|
    #  @config["HOSTS"][host]['roles'].each do |role|
    #    if /agent/ =~ role then               # If the host is puppet agent
    #      BeginTest.new(host, test_name)
    #      runner = RemoteExec.new(host)
    #      result = runner.do_remote("puppet agent --no-daemonize --verbose --onetime --test --waitforcert 10 &")
    #      @fail_flag+=result.exit_code
    #      result.log(test_name)
    #    end
    #  end
    #end

    # Sign Agent Certs from PMASTER
    test_name="Puppet Master Sign Requested Agent Certs"
    BeginTest.new(master, test_name)
    runner = RemoteExec.new(master)
    result = runner.do_remote("puppet cert --sign #{agent_list}")
    @fail_flag+=result.exit_code
    result.log(test_name)

  end
end
