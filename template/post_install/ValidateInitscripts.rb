# Post install checks
# Verify pe-httpd, pe-puppet, mysqld init scripts are set correctly


hosts.each do |host|
  next unless platform =  host['platform'].include?('centos') || host['platform'].include?('rhel')
  role_agent     = host['roles'].include? 'agent'
  role_master    = host['roles'].include? 'master'
  role_dashboard = host['roles'].include? 'dashboard'

  if (role_agent && !role_dashboard && !role_master)   # pe-puppet only
    on host,"chkconfig --list | grep pe- | grep 'pe-puppet.*0:off.1:off.2:on.3:on.4:on.5:on.6:off'"
  end

  if (role_dashboard || role_master)   # pe-httpd & pe-puppet & mysqld should be running too
    step "Validate pe-httpd and pe-puppet init scripts"
    on host,"chkconfig --list | grep pe- | grep -e 'pe-httpd.*0:off.1:off.2:on.3:on.4:on.5:on.6:off' -e 'pe-puppet.*0:off.1:off.2:on.3:on.4:on.5:on.6:off'"
    step "Validate mysql init scripts"
    on host,"chkconfig --list | grep 'mysqld.*0:off.1:off.2:on.3:on.4:on.5:on.6:off'"
  end
end
