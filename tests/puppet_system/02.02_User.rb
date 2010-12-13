
initpp="/etc/puppetlabs/puppet/modules/puppet_system_test/manifests"
# Write new class to init.pp
prep_initpp(master, "user", initpp) 

# Initiate transfer: puppet agent -t
test_name="User Resource: puppet agent --no-daemonize --verbose --onetime --test"

agents.each do |host|
  agent_run = RemoteExec.new(host)    # get remote exec obj to agent
  BeginTest.new(host, test_name)
  result = agent_run.do_remote("puppet agent --no-daemonize --verbose --onetime --test")
  result = agent_run.do_remote("puppet agent --no-daemonize --verbose --onetime --test")
  result.log(test_name)
end

# verify files have been transfered to agents
test_name="Verify User Existence on Agents"
agents.each do |host|
  agent_run = RemoteExec.new(host)     # get remote exec obj to agent
  BeginTest.new(host, test_name)
  result = agent_run.do_remote('cat /etc/passwd | grep -c PuppetTestUser')
  result.log(test_name)
  if (result.stdout =~ /3/ ) then
    puts "Users created correctly"
  else
    puts "Error creating users"
  end
  @fail_flag+=1
end
