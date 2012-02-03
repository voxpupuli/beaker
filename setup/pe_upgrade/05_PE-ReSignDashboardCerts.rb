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

skip_test "Only need to set up multi-node certs if we are starting with a version of 1.2" and break unless options[:upgrade] =~ /^1\.2/

skip_test "Only need to set up multi-node certs if we have a puppet master" and
  break unless role_master

skip_test "Only need to set up multi-node certs if we have a dashboard" and
  break unless dashboard_host

skip_test "Only need to set up multi-node certs if dashboard and master are not installed on the same node" and break if role_master_dashboard

skip_test "This test expects that the dashbaord has an agent installed" and break unless agents.include? dashboard_host

test_name 'Set up certificates when the dashboard and master are on seperate nodes.'
#  set up certs if we have a dashbaord with an agent
# this represents the manual steps that have to be run when the dashboard
# and puppet master are installed on different machines.

step 'set up dashboard certificates'

on dashboard_host, 'cd /opt/puppet/share/puppet-dashboard; /opt/puppet/bin/rake cert:request'

on master, puppet("cert --sign pe-internal-dashboard")

on dashboard_host, 'cd /opt/puppet/share/puppet-dashboard; /opt/puppet/bin/rake cert:retrieve'

step 'start puppet master and inventory service'
on dashboard_host, '/etc/init.d/pe-httpd start'
