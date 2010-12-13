file_count=10  # Default files to create

# parse config file for file count
@config["CONFIG"].each_key do|cfg|
  if cfg =~ /filecount/ then							#if the config hash key is filecount
    file_count = @config["CONFIG"][cfg]		#then filecount value is num of files to create
  end
end
puts "Verifying #{file_count} files"

# Initiate transfer: puppet agent
test_name="Initiate Directory Transfer on Agents"
agents.each do |host|
  agent_run = RemoteExec.new(host)    # get remote exec obj to agent
  BeginTest.new(host, test_name)
  result = agent_run.do_remote("puppet agent --no-daemonize --verbose --onetime --test")
  result = agent_run.do_remote("puppet agent --no-daemonize --verbose --onetime --test")
  result.log(test_name)
  #@fail_flag+=result.exit_code
end

# verify files have been transfered to agents
test_name="Verify Directory Existence on Agents"
agents.each do |host|
  agent_run = RemoteExec.new(host)    # get remote exec obj to agent
  BeginTest.new(host, test_name)
  result = agent_run.do_remote("/ptest/bin/fileserve.sh /root dir #{file_count}")
  result.log(test_name)
  @fail_flag+=result.exit_code
end
