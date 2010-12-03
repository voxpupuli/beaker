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

    # parse config file for file count
    @config["CONFIG"].each_key do|cfg|
      if cfg =~ /filecount/ then							#if the config hash key is filecount
        file_count = @config["CONFIG"][cfg]		#then filecount value is num of files to create
      end
    end
    puts "Creating #{file_count} files"

		# Initiate transfer: puppet agent -t
		test_name="Initiate File Transfer on Agents"
    @config["HOSTS"].each_key do|host|
      @config["HOSTS"][host]['roles'].each do |role|
        if /agent/ =~ role then               # If the host is puppet agent
   		    agent_run = RemoteExec.new(host)    # get remote exec obj to agent
	  	    BeginTest.new(host, test_name)
		      result = agent_run.do_remote("puppet agent --server #{master} --no-daemonize --verbose --onetime --test")
          ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)
          @fail_flag+=result.exit_code
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
          ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)
          @fail_flag+=result.exit_code
        end
      end
    end

  end
end
