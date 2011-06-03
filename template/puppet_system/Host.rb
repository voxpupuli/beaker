
# Write new class to init.pp
prep_initpp(master, "host")

# Initiate transfer: puppet agent 
step "Host file management: puppet agent --no-daemonize --verbose --onetime --test"
run_agent_on agents

step "Verify host file modification on Agents"
agents.each { |agent|
  on agent,"grep -P '9.10.11.12\\W+puppethost3\\W+ph3.alias.1\\W+ph3.alias.2' /etc/hosts"
  on agent,"grep -P '5.6.7.8\\W+puppethost2\\W+ph2.alias.1' /etc/hosts"
  on agent,"grep -P '1.2.3.4\\W+puppethost1.name' /etc/hosts"
}
