# Accepts hash of parsed config file as arg
class User
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
    prep_initpp(master, "user", "#{initpp}") 

		# Initiate transfer: puppet agent -t
		test_name="User Resource: puppet agent --no-daemonize --verbose --onetime --test"

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

		# verify files have been transfered to agents
		test_name="Verify User Existence on Agents"
    @config["HOSTS"].each_key do|host|
      @config["HOSTS"][host]['roles'].each do |role|
        if /agent/ =~ role then                # If the host is puppet agent
		      agent_run = RemoteExec.new(host)     # get remote exec obj to agent
		      BeginTest.new(host, test_name)
		      result = agent_run.do_remote('cat /etc/passwd | grep -c PuppetTestUser')
          ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)
          if (result.stdout =~ /3/ ) then
            puts "Users created correctly"
          else
            puts "Error creating users"
            @fail_flag+=1
          end
        end
      end
    end

  end
end
