# Accepts hash of parsed config file as arg
class FileServe
  attr_accessor :config, :fail_flag
  def initialize(config)
    self.config    = config
    self.fail_flag = 0

    host=""
    master=""
    agent=""
    usr_home=ENV['HOME']
    @fail_flag=0

    @config.each_key do|host|
      @config[host]['roles'].each do|role|
        if /master/ =~ role then        # If the host is puppet master
          master=host
        elsif /agent/ =~ role then      # If the host is puppet agent
          agent=host
        end
      end # /role
    end

		master_run = RemoteExec.new(master)  # get remote exec obj to master
		agent_run = RemoteExec.new(agent)    # get remote exec obj to agent

    # TODO  This should moved to a post install setup
    test_name="Fileserve(setup) step 1 -- SCP puppet.tgz to Puppet Master"
    # 0: SCP puppet.tgz
    BeginTest.new(master, test_name)
    scper = ScpFile.new(master)
    result = scper.do_scp("#{$work_dir}/puppet.tgz", "/etc/puppetlabs")
    @fail_flag+=result.exit_code
    ChkResult.new(master, test_name, result.stdout, result.stderr, result.exit_code)
  
    sleep 17

    # 1: Now untar puppet.tgz 
    test_name="Fileserve(setup) step 2 -- untar puppet.tgz on Puppet Master"
		BeginTest.new(master, test_name)
		result = master_run.do_remote('cd /etc/puppetlabs && tar xzf puppet.tgz')
    @fail_flag+=result.exit_code
    ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)

		# 2: invoke puppet agent -t
		test_name="File Serve step 3"
    @config.each_key do|host|
      @config[host]['roles'].each do|role|
        if /agent/ =~ role then      # If the host is puppet agent
          agent=host
   		    agent_run = RemoteExec.new(agent)    # get remote exec obj to agent
	  	    BeginTest.new(agent, test_name)
		      result = agent_run.do_remote("puppet agent --test --server #{master}")
          ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)
          @fail_flag+=result.exit_code
        end
      end
    end

		# 3: verify files have been transfered to agents
		test_name="File Serve step 5"
    @config.each_key do|host|
      @config[host]['roles'].each do|role|
        if /agent/ =~ role then      # If the host is puppet agent
          agent=host
		      agent_run = RemoteExec.new(agent)    # get remote exec obj to agent
		      BeginTest.new(agent, test_name)
		      result = agent_run.do_remote('/root/remote_exec/fileserve.sh')
          ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)
          @fail_flag+=result.exit_code
        end
      end
    end
  end
end
