file_count=10  # Default files to create

# Initiate transfer: puppet agent
test_name="Initiate File Transfer on Agents"
agents.each do |host|
  agent_run = RemoteExec.new(host)    # get remote exec obj to agent
  BeginTest.new(host, test_name)
  result = agent_run.do_remote("puppet agent --no-daemonize --verbose --onetime --test")
  result = agent_run.do_remote("puppet agent --no-daemonize --verbose --onetime --test")
  result.log(test_name)
  #@fail_flag+=result.exit_code
end

# verify sized (0, 10, 100K)) files have been transfered to agents
test_name="Verify File Existence on Agents"
agents.each do |host|
  agent_run = RemoteExec.new(host)    # get remote exec obj to agent
  BeginTest.new(host, test_name)
  result = agent_run.do_remote('/ptest/bin/fileserve.sh /root files')
  result.log(test_name)
  @fail_flag+=result.exit_code
end
