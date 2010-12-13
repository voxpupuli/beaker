
initpp="/etc/puppetlabs/puppet/modules/puppet_system_test/manifests"
# Write new class to init.pp
prep_initpp(master, "host", initpp)

# Initiate transfer: puppet agent 
test_name="Host file management: puppet agent --no-daemonize --verbose --onetime --test"

agents.each do |host|
  agent_run = RemoteExec.new(host)    # get remote exec obj to agent
  BeginTest.new(host, test_name)
  result = agent_run.do_remote("puppet agent --no-daemonize --verbose --onetime --test")
  result = agent_run.do_remote("puppet agent --no-daemonize --verbose --onetime --test")
  result.log(test_name)
end

#verify correct host file mods
test_name="Verify host file modification on Agents"
agents.each do |host|
  BeginTest.new(host, test_name)
  agent_run = RemoteExec.new(host)     # get remote exec obj to agent
  result = agent_run.do_remote("grep -P '9.10.11.12\\W+puppethost3\\W+ph3.alias.1\\W+ph3.alias.2' /etc/hosts")
  result.log(test_name)
  @fail_flag+=result.exit_code
  result = agent_run.do_remote("grep -P '5.6.7.8\\W+puppethost2\\W+ph2.alias.1' /etc/hosts")
  result.log(test_name)
  @fail_flag+=result.exit_code
  result = agent_run.do_remote("grep -P '1.2.3.4\\W+puppethost1.name' /etc/hosts")
  result.log(test_name)
  @fail_flag+=result.exit_code
end
