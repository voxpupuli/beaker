#
# This step sets up certificates for the case
# when the dashbaord is split up from the puppetmaster
#
role_master = FALSE
role_agent = FALSE
role_master_dashboard = FALSE
dashboard_host = nil
# figure out if we have a master, dashboard, and if they are installed on the same machine
hosts.each do |host|
  # collect the hosts that correspond to these roles
  role_master_dashboard = TRUE if host['roles'].include? 'master' and host['roles'].include? 'dashboard'
  if host['roles'].include? 'dashboard'
    dashboard_host = host
  end
  role_master=TRUE if host['roles'].include? 'master'
  role_agent=TRUE if host['roles'].include? 'agent'
end

# we are only testing when we have a dashboard and master on different machines
# and only if the dashboard has an agent installed on the same machine
skip_test "Only need to set up multi-node certs if we have a puppet master" and break unless role_master
skip_test "Only need to set up multi-node certs if we have a dashboard" and break unless dashboard_host
skip_test "Only need to set up multi-node certs if dashboard and master are not installed on the same node" and break if role_master_dashboard
skip_tests "This test expects that the dashbaord has an agent installed" and break unless agents.include? dashboard_host

test_name 'Set up certificates when the dashboard and master are on seperate nodes.'
#  set up certs if we have a dashbaord with an agent
# this represents the manual steps that have to be run when the dashboard
# and puppet master are installed on different machines.

step 'set up dashboard certificates'
# send dashboard csr
on dashboard_host, 'cd /opt/puppet/share/puppet-dashboard; PATH=/opt/puppet/sbin:/opt/puppet/bin:$PATH rake RAILS_ENV=production cert:request'
# sign dashboard cert
on master, "puppet cert --sign dashboard"
# retreive dashboard cert
on dashboard_host, 'cd /opt/puppet/share/puppet-dashboard; PATH=/opt/puppet/sbin:/opt/puppet/bin:$PATH rake RAILS_ENV=production cert:retrieve'
step 'retrieve inventory service certificate.'
on dashboard_host, "/opt/puppet/bin/ruby /opt/puppet/bin/receive_signed_cert.rb #{dashboard_host} #{master}"
step 'start puppet master and inventory service'
on dashboard_host, '/etc/init.d/pe-httpd start'
