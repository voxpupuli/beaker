test_name "Puppet Master santiy checks: PID file and SSL dir creation"

puppetpath = '/etc/puppet'
pidfile = '/var/lib/puppet/run/master.pid'

# TODO: Need to expose this data
# config["CONFIG"].each_key do|cfg|
#  puts "Config Key|Val: #{cfg} #{config["CONFIG"][cfg].inspect}"
# end

# SSL dir exists?
step "Check for previously existing SSL dir"
on master, "rm -rf #{puppetpath}/ssl || echo ssl dir not present"

# Kill running Puppet Master -- should not be running at this point
step "Master: kill running Puppet Master"
on master, "ps -U puppet | awk '/puppet/ { print \$1 }' | xargs kill || echo \"Puppet Master not running\""

step "Master: Start Puppet Master"
on master, puppet_master("--certdnsnames=\"puppet:$(hostname):$(hostname -f)\" --verbose --noop")

# SSL dir created?
step "SSL dir created?"
on master,  "if [ -d #{puppetpath} ] ; then echo \"SSL dir created\"; fi"

# PID file exists?
step "PID file created?"
on master, "if [ -f #{pidfile} ] ; then echo \"PID file created\"; fi" 

# Kill running Puppet Master
step "Master: kill running Puppet Master"
on master, "ps -U puppet | awk '/puppet/ { print \$1 }' | xargs kill"
