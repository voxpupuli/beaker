

master = hosts(/master/).first

# Write new class to init.pp
prep_initpp(master, "group", "/etc/puppetlabs/puppet/modules/puppet_system_test/manifests")

#Initiate transfer: puppet agent 
test_name="Group Resource: puppet agent --no-daemonize --verbose --onetime --test"

hosts(/agent/).each do |host|
  agent_run = RemoteExec.new(host)    # get remote exec obj to agent
  BeginTest.new(host, test_name)
  result = agent_run.do_remote("puppet agent --no-daemonize --verbose --onetime --test")
  result = agent_run.do_remote("puppet agent --no-daemonize --verbose --onetime --test")
  result.log(test_name)
end

#verify files have been transfered to agents
test_name="Verify Group Existence on Agents"
hosts(/agent/).each do |host|
  agent_run = RemoteExec.new(host)     # get remote exec obj to agent
  BeginTest.new(host, test_name)
  result = agent_run.do_remote('cat /etc/group | grep -c puppetgroup')
  result.log(test_name)
  if result.stdout =~ /3/ then
    puts "Group created correctly"
  else
    puts "Error creating group"
    @fail_flag+=1
  end
end
