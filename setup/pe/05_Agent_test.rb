test_name "Agent --test post install"
step 'Running puppet agent --test on each agent'

sleep 20

on agents, puppet_agent('--test'), :acceptable_exit_codes => [0,2]
