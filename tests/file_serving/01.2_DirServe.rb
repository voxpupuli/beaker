# Accepts hash of parsed config file as arg
class DirServe
  attr_accessor :config, :fail_flag
  def initialize(config)
    self.config    = config
    self.fail_flag = 0

    usr_home=ENV['HOME']
    @fail_flag=0


		# Initiate transfer: puppet agent -t
		test_name="Initiate Directory Transfer on Agents"
    @config.each_key do|host|
      @config[host]['roles'].each do|role|
        if /agent/ =~ role then      # If the host is puppet agent
          agent=host
   		    agent_run = RemoteExec.new(agent)    # get remote exec obj to agent
	  	    BeginTest.new(agent, test_name)
		      result = agent_run.do_remote("puppet agent --test")
          ChkResult.new(agent, test_name, result.stdout, result.stderr, result.exit_code)
          @fail_flag+=result.exit_code
        end
      end
    end

		# verify files have been transfered to agents
		test_name="Verify Directory Existence on Agents"
    @config.each_key do|host|
      @config[host]['roles'].each do|role|
        if /agent/ =~ role then      # If the host is puppet agent
          agent=host
		      agent_run = RemoteExec.new(agent)    # get remote exec obj to agent
		      BeginTest.new(agent, test_name)
		      result = agent_run.do_remote('/ptest/bin/fileserve.sh /root dir')
          ChkResult.new(agent, test_name, result.stdout, result.stderr, result.exit_code)
          @fail_flag+=result.exit_code
        end
      end
    end

  end
end
