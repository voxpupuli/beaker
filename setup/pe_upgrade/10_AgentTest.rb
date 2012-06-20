test_name "Agent --test post install"

agents.each do |agent|
  step "Stopping puppet agent on #{agent}"

  if agent['platform'].include?('solaris')
    on(agent, '/usr/sbin/svcadm disable -s svc:/network/puppetagent:default')
  elsif agent['platform'].include?('debian') or agent['platform'].include?('ubuntu')
    on(agent, '/etc/init.d/pe-puppet-agent stop')
  elsif agent['platform'].include?('windows')
    on(agent, 'net stop puppet', :acceptable_exit_codes => [0,2])
  else
    on(agent, '/etc/init.d/pe-puppet stop')
  end
end

step 'Sleeping'
sleep 20

step 'Running puppet agent --test on each agent'
on agents, puppet_agent('--test'), :acceptable_exit_codes => [0,2]
