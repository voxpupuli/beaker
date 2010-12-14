# Test Template

# Very simple test case

step "Perform same action on each host"
on hosts,'uname'

step "Perform specific action based on host's role"
on master,"puppet master specific command"
on agents,"puppet agent specific command"
on dashboard,"puppet dashboard specific command"
