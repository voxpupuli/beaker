# Accepts hash of parsed config file as arg
class Host
  attr_accessor :config, :fail_flag
  def initialize(config)
    self.config    = config
    self.fail_flag = 0

    @fail_flag=0

    master=""
    @config["HOSTS"].each_key do|host|
      @config["HOSTS"][host]['roles'].each do |role|
        #master=host if /master/ =~ role  # Host is a puppet master
        if /master/ =~ role then
          master=host
        end
      end
    end

    initpp="/etc/puppetlabs/puppet/modules/puppet_system_test/manifests"
    # Write new class to init.pp
    prep_initpp(master, "host", "#{initpp}")

		# Initiate transfer: puppet agent 
		test_name="Host file management: puppet agent --no-daemonize --verbose --onetime --test"

    @config["HOSTS"].each_key do|host|
      @config["HOSTS"][host]['roles'].each do |role|
        if /agent/ =~ role then               # If the host is puppet agent
   		    agent_run = RemoteExec.new(host)    # get remote exec obj to agent
	  	    BeginTest.new(host, test_name)
		      result = agent_run.do_remote("puppet agent --no-daemonize --verbose --onetime --test")
		      result = agent_run.do_remote("puppet agent --no-daemonize --verbose --onetime --test")
          ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)
        end
      end
    end

		# verify correct host file mods
		test_name="Verify host file modification on Agents"
    @config["HOSTS"].each_key do|host|
      @config["HOSTS"][host]['roles'].each do |role|
        if /agent/ =~ role then                # If the host is puppet agent
		      BeginTest.new(host, test_name)
		      agent_run = RemoteExec.new(host)     # get remote exec obj to agent
		      result = agent_run.do_remote("grep -P '9.10.11.12\\W+puppethost3\\W+ph3.alias.1\\W+ph3.alias.2' /etc/hosts")
          ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)
          @fail_flag+=result.exit_code
		      result = agent_run.do_remote("grep -P '5.6.7.8\\W+puppethost2\\W+ph2.alias.1' /etc/hosts")
          ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)
          @fail_flag+=result.exit_code
		      result = agent_run.do_remote("grep -P '1.2.3.4\\W+puppethost1.name' /etc/hosts")
          ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)
          @fail_flag+=result.exit_code
        end
      end
    end

  end
end
