test_name "Agent --test post install"
step 'Running pupept agent --test on each agent'
agents.each do |agent|
  if agent['platform'].include?('solaris')
    on(agent, '/usr/sbin/svcadm disable -s svc:/network/puppetagent:default')
    on(agent, puppet_agent("--test"), :acceptable_exit_codes => [0,2])
    on(agent, '/usr/sbin/svcadm enable svc:/network/puppetagent:default')
  elsif agent['platform'].include?('debian') or agent['platform'].include?('ubuntu')
    on(agent, '/etc/init.d/pe-puppet-agent stop')
    on(agent, puppet_agent("--test"), :acceptable_exit_codes => [0,2])
    on(agent, '/etc/init.d/pe-puppet-agent start')
  else
    on(agent, '/etc/init.d/pe-puppet stop')
    on(agent, puppet_agent("--test"), :acceptable_exit_codes => [0,2])
    on(agent, '/etc/init.d/pe-puppet start')
  end
end
