prep_initpp(master, "user")

# Initiate transfer: puppet agent -t
step "User Resource: puppet agent --no-daemonize --verbose --onetime --test"
run_agent_on agents

step "Verify User Existence on Agents"
agents.each { |agent|
  on agent,'cat /etc/passwd | grep -c PuppetTestUser'
  if ! (result.stdout =~ /3/ ) then
    fail_test "Error creating users"
  end
}
