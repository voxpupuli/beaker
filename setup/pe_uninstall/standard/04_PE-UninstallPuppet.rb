test_name 'Ensure the Unistaller works against a basic PE Install'

cronjobs =      [ '.d/default-add-all-nodes', '.hourly/puppet_baselines.sh' ]

directories =   [ '/opt/puppet', '/var/opt/lib/pe-puppet',
                  '/var/opt/lib/pe-puppetmaster',
                  '/var/opt/cache/pe-puppet-dashboard', '/var/opt/puppet' ]

processes =     [ 'puppetagent', 'pe-puppet', 'pe-puppet-agent',
                  'pe-mcollective', 'pe-httpd', 'pe-activemq', 'pe-memcached',
                  'pe-dashboard-workers' ]

users_groups =  [ 'pe-memcached', 'pe-apache', 'pe-puppet', 'puppet-dashboard',
                  'pe-activemq', 'peadmin', 'pe-mco' ]

symlinks =      [ 'puppet', 'facter', 'puppet-module', 'mco', 'pe-man' ]


step 'Test -h option'
hosts.each do |host|
  on host, "cd /tmp/puppet-enterprise-#{config['pe_ver']}-#{host['platform']}" +
    '&& ./puppet-enterprise-uninstaller -h' do

    assert_no_match /ERROR/, stdout, '`-h` does not seem to be a valid option'
    assert_match /Display this help screen/, stdout,
      'The help screen is not displayed'
  end
end

step 'Standard Uninstall'
hosts.each do |host|
  on host, "cd /tmp/puppet-enterprise-#{config['pe_ver']}-#{host['platform']}" +
    '&& ./puppet-enterprise-uninstaller -y'
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

  # remove cron files
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
step 'Confirm Removal of Packages'
hosts.each do |host|
  cmd = case host['platform']
  when /ubuntu|debian/
    " ! ls /tmp/puppet-enterprise-#{config['pe_ver']}-#{host['platform']}/packages/#{host['platform']}" +
    "| xargs dpkg-query --showformat='${Status;10}' --show " +
    '| egrep \(ok\|install\)'
  when /el|sles/
    " ! rpm -qp --qf '%{name} ' " +
    "/tmp/puppet-enterprise-#{config['pe_ver']}-#{host['platform']}/packages/#{host['platform']}/**" +
    "| xargs rpm -q | grep -v 'not installed'"
  when /solaris/
    "ls /tmp/puppet-enterprise-#{config['pe_ver']}-#{host['platform']}/packages/#{host['platform']}/ " +
    '| cut -d- -f2 | while read pkg; do pkginfo -q "PUP${pkg}"; ' +
    'if test $? -eq 0; then echo "found package ${pkg}"; exit 1; fi; done'
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
