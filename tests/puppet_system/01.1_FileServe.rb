# Accepts hash of parsed config file as arg
class FileServe
  attr_accessor :config, :fail_flag
  def initialize(config)
    self.config    = config
    self.fail_flag = 0

    @fail_flag=0
    file_count=10  # Default files to create
    master=""

    # Parse config for Master 
    @config["HOSTS"].each_key do|host|
      @config["HOSTS"][host]['roles'].each do |role|
        if /master/ =~ role then         # Detect Puppet Master node
          master = host
        end
      end
    end

		# Initiate transfer: puppet agent
		test_name="Initiate File Transfer on Agents"
    @config["HOSTS"].each_key do|host|
      @config["HOSTS"][host]['roles'].each do |role|
        if /agent/ =~ role then               # If the host is puppet agent
   		    agent_run = RemoteExec.new(host)    # get remote exec obj to agent
	  	    BeginTest.new(host, test_name)
		      result = agent_run.do_remote("puppet agent --no-daemonize --verbose --onetime --test")
		      result = agent_run.do_remote("puppet agent --no-daemonize --verbose --onetime --test")
          result.log(test_name)
          #@fail_flag+=result.exit_code
        end
      end
    end

		# verify sized (0, 10, 100K)) files have been transfered to agents
		test_name="Verify File Existence on Agents"
    @config["HOSTS"].each_key do|host|
      @config["HOSTS"][host]['roles'].each do |role|
        if /agent/ =~ role then                # If the host is puppet agent
		      agent_run = RemoteExec.new(host)    # get remote exec obj to agent
		      BeginTest.new(host, test_name)
		      result = agent_run.do_remote('/ptest/bin/fileserve.sh /root files')
          result.log(test_name)
          @fail_flag+=result.exit_code
        end
      end
    end

  end
end
