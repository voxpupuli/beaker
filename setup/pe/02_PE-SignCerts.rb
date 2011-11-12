# Agents certs will remain waiting for signing on master until this step
#

role_master_dashboard = FALSE
hosts.each do |host| 
  role_master_dashboard = TRUE if host['roles'].include? 'master' and host['roles'].include? 'dashboard'
end
skip_test "Master and Dashboard are on sepreate hosts, skipping this step" and break unless role_master_dashboard 

step "Puppet Master/Dashboard single host:  Sign Requested Agent Certs"
hosts.each do |host| 
  # Master auto signs its own cert on startup
  next if host['roles'].include? 'master'
  on master, puppet("cert --sign #{host}") do
    assert_no_match(/Could not call sign/, stdout, "Unable to sign cert for #{host}")
  end
end
