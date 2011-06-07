test_name "Puppet Master santiy checks: PID file and SSL dir creation"

pidfile = '/var/lib/puppet/run/master.pid'

# SSL dir exists?
step "Check for previously existing SSL dir"
on master, "rm -rf #{master['puppetpath']}/ssl"

with_master_running_on(master, "--certdnsnames=\"puppet:$(hostname -s):$(hostname -f)\" --verbose --noop") do
  # SSL dir created?
  step "SSL dir created?"
  on master,  "[ -d #{master['puppetpath']}/ssl ]"

  # PID file exists?
  step "PID file created?"
  on master, "[ -f #{pidfile} ]"
end
