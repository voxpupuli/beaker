# Validate Cert Signing
# Accepts hash of parsed config file as arg
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

    # AGENT(s) intiate Cert Signing with PMASTER
    @config["HOSTS"].each_key do|host|
      @config["HOSTS"][host]['roles'].each do |role|
        if /agent/ =~ role then               # If the host is puppet agent
          BeginTest.new(host, test_name)
          runner = RemoteExec.new(host)
          result = runner.do_remote("puppet agent --server #{master} --no-daemonize --verbose --onetime --test")
          @fail_flag+=result.exit_code
          ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)
        end
      end
    end
    sleep 2

    # Sign Agent Certs from PMASTER
    test_name="Puppet Master Sign Requested Agent Certs"
    BeginTest.new(master, test_name)
    runner = RemoteExec.new(master)
    result = runner.do_remote("puppet cert --sign #{agent_list}")
    @fail_flag+=result.exit_code
    ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)

  end
end
