# Agents certs will remain waiting for signing on master until this step
#

step 'Wait for slow agents to initialize'
sleep 10

step 'Sign Requested Agent Certs'
on master, puppet("cert --sign --all"), :acceptable_exit_codes => [0,24]
