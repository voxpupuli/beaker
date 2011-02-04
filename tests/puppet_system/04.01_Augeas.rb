# Test Augues functionality
# Include new class to init.pp
prep_initpp(master, "augeas")

# Initiate transfer: puppet agent 
step "Run: puppet agent --no-daemonize --verbose --onetime --test"
run_agent_on agents

step "Verify Augeas modification to /etc/ssh/sshd_config"
agents.each { |agent|
  on agent,"grep 'PermitEmptyPasswords yes' /etc/ssh/sshd_config"
}

# Idempotence check: re-Initiate transfer
step "Idempotence check re-run: puppet agent --no-daemonize --verbose --onetime --test"
run_agent_on agents

step "Verify augeas NO modification to /etc/ssh/sshd_config"
agents.each { |agent|
  on agent,"grep 'PermitEmptyPasswords yes' /etc/ssh/sshd_config"
}
