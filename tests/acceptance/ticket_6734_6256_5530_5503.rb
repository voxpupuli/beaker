# Puppet master fails to start due to impropper 
# permissons on the puppet/ dir.  Specially, the rrd 
# sub dir is not created when puppet master starts
 
test_name "Tickets 6734 6256 5530 5503i Puppet Master fails to start"

# Kill running Puppet Master
step "Check for running Puppet Master"
on master, "ps -ef | grep puppet"
  fail_test "Puppet Master not running" unless
    stdout.include? 'master'

step "Check permissions on puppet/rrd/"
on master, "ls -Z /var/lib/puppet | grep rrd"
  fail_test "puppet/rrd does not exit/wrong permission" unless
    stdout.include? 'puppet puppet'
