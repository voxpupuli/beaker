prep_initpp(master, "user") 

# Initiate transfer: puppet agent -t
step "User Resource: puppet agent --no-daemonize --verbose --onetime --test"
run_agent_on agents

step "Verify User Existence on Agents"
agents.each { |agent|
  on agent,'cat /etc/passwd | grep -c PuppetTestUser'
  if (result.stdout =~ /3/ ) then
    puts "Users created correctly"
  else
    puts "Error creating users"
    @fail_flag += 1
  end
}