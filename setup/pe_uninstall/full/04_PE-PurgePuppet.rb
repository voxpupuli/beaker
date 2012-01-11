test_name 'Ensure the Unistaller works against a basic PE Install with noop and while purging, cleaning db using an answer file'

cronjobs =      [ '.d/default-add-all-nodes', '.hourly/puppet_baselines.sh' ]

directories =   [ '/opt/puppet', '/var/opt/lib/pe-puppet',
                  '/var/opt/lib/pe-puppetmaster', '/etc/puppetlabs',
                  '/var/opt/cache/pe-puppet-dashboard', '/var/opt/puppet' ]

processes =     [ 'puppetagent', 'pe-puppet', 'pe-puppet-agent',
                  'pe-mcollective', 'pe-httpd', 'pe-activemq', 'pe-memcached',
                  'pe-dashboard-workers' ]

users_groups =  [ 'pe-memcached', 'pe-apache', 'pe-puppet', 'puppet-dashboard',
                  'pe-activemq', 'peadmin', 'pe-mco' ]

symlinks =      [ 'puppet', 'facter', 'puppet-module', 'mco', 'pe-man' ]


step 'Make sure Noop Mode does no harm'
hosts.each do |host|
  on host, "cd /tmp/puppet-enterprise-#{config['pe_ver']}-#{host['platform']}/" +
    '&& ./puppet-enterprise-uninstaller -yn'

  if host['platform'] =~ /debian|ubuntu/
    agent_service = 'pe-puppet-agent'
  else
    agent_service = 'pe-puppet'
  end

  if host['platform'] =~ /solaris/
    stop_cmd = '/usr/sbin/svcadm disable -s svc:/network/puppetagent:default'
  else
    stop_cmd = "/etc/init.d/#{agent_service} stop"
  end

  on host, stop_cmd
  on host, puppet('agent -t'), :acceptable_exit_codes => [0,2]

end

step 'Create Answer file'
hosts.each do |host|
  on host, "cat > /tmp/answer_file <<EOF
q_pe_uninstall=y
q_pe_purge=y
q_pe_remove_db=#{ host['roles'].include?('dashboard') ? 'y' : 'n'}
q_pe_db_root_pass=puppet
EOF"
end

step 'Uninstall!'
hosts.each do |host|
  on host, "cd /tmp/puppet-enterprise-#{config['pe_ver']}-#{host['platform']}/ " +
    '&& ./puppet-enterprise-uninstaller -a ../answer_file'
end

step 'Confirm Uninstallation'
step 'Confirm Removal of Directories'
hosts.each do |host|
  directories.each do |dir|
    on host, "test -d #{dir}",
      :acceptable_exit_codes => [1]
  end
end

step 'Confirm Removal of Files'
hosts.each do |host|
  processes.each do |process|

    # Ensure our init scripts are gone
    on host, "test -f /etc/init.d/#{process}",
      :acceptable_exit_codes => [1]

    # Ensure there are no process files or directories
    on host, "ls /var/run | grep #{process}",
      :acceptable_exit_codes => [1]

    # lock files are in /var/lock/{process_name}/ in debs,
    # /var/lock/subsys{process_name} in els
    on host, "ls /var/lock | grep #{process}",
      :acceptable_exit_codes => [1]
    on host, "ls /var/lock/subsys | grep #{process}",
      :acceptable_exit_codes => [1]

    on host, "ls /var/log | grep #{process}",
      :acceptable_exit_codes => [1]

  end

  symlinks.each do |sym|
    on host, "test -f /usr/local/bin/#{sym}",
      :acceptable_exit_codes => [1]
  end

  # Ensure removal of cronjobs
  cronjobs.each do |cronjob|
    on host, "test -f /etc/cron#{cronjob}",
      :acceptable_exit_codes => [1]
  end
end

step 'Confirm Removal of Users and Groups'
hosts.each do |host|
  users_groups.each do |usr_grp|
    on host, "cat /etc/passwd | grep #{usr_grp}",
      :acceptable_exit_codes => [1]
    on host, "cat /etc/group | grep #{usr_grp}",
      :acceptable_exit_codes => [1]
  end
end

# There should be no PE packages on the system, this should ensure all PE
# packages and nothing but PE packages are checked
step 'Confirm Removal of Packages WIP'
hosts.each do |host|
  cmd = case host['platform']
  when /ubuntu|debian/
    " ! ls /tmp/puppet-enterprise-#{config['pe_ver']}-#{host['platform']}/packages/#{host['platform']}" +
    "| xargs dpkg-query --showformat='${Status;10}' --show " +
    '| egrep \(ok\|install\)'
  when /el|sles/
    " ! rpm -qp --qf '%{name} ' " +
    "/tmp/puppet-enterprise-#{config['pe_ver']}-#{host['platform']}/packages/el-5-i386/**" +
    "| xargs rpm -q | grep -v 'not installed'"
  when /solaris/
    "ls /tmp/puppet-enterprise-#{config['pe_ver']}-#{host['platform']}/packages/solaris-10-i386/ " +
    '| cut -d- -f2 | while read pkg; do pkginfo -q "PUP${pkg}"; if test $? -eq 0;' +
    ' then exit 1; fi; done'
  end

  on host, "#{cmd}"

end

# Chkconfig is not cross platform, though symlinks in /etc/rc* are, I believe
step 'Confirm Removal of Processes from start up'
hosts.each do |host|
  processes.each do |process|

    next if process =~ /pe-dashboard-workers/

    on host, "grep -Rl #{process} /etc/rc*",
      :acceptable_exit_codes => [1, 2]
  end
end

step 'Ensure database is removed'
hosts.each do |host|
  next unless host['roles'].include? 'dashboard'

  # We should not be able to log into mysql with the PE created user
  on host, " ! mysql --user=console --password=puppet"

  # We should not be able to use the console db
  on host, " ! mysql --user=root --password=puppet -e 'use console'"

end

