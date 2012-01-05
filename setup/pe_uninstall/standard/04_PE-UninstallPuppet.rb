test_name 'Ensure the Unistaller works against a basic PE Install'

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
    on host, " ! [[ -d #{dir} ]]"
  end
end

step 'Confirm Removal of Files'
hosts.each do |host|
  processes.each do |process|

    # Ensure our init scripts are gone
    on host, " ! [[ -f /etc/init.d/#{process} ]]"

    # Ensure there are no process files or directories
    on host, " ! ls /var/run | grep #{process} "

    # lock files are in /var/lock/{process_name}/ in debs,
    # /var/lock/subsys{process_name} in els
    on host, " ! ls /var/lock | grep #{process} "
    on host, " ! ls /var/lock/subsys | grep #{process} "

    on host, " ! ls /var/log | grep #{process} "

  end

  symlinks.each do |sym|
    on host, " ! [[ -f /usr/local/bin/#{sym} ]]"
  end
end

step 'Confirm Removal of Users and Groups'
hosts.each do |host|
  users_groups.each do |usr_grp|
    on host, " ! cat /etc/passwd | grep #{usr_grp}"
    on host, " ! cat /etc/group | grep #{usr_grp}"
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
    "| egrep \(ok\|install\)"
  when /el|sles/
    " ! rpm -qp --qf '%{name} ' " +
    "/tmp/puppet-enterprise-#{config['pe_ver']}-#{host['platform']}/packages/el-5-i386/" +
    "| xargs rpm -q | grep -v 'not installed'"
  when /solaris/
    'ls /tmp/puppet-enterprise-2.0.0-94-g6234c76-solaris-10-i386/packages/solaris-10-i386/ ' +
    '| cut -d- -f2 | while read pkg; do pkginfo -q "PUP${pkg}"; ' +
    'if test $? -eq 0; then exit 1; fi; done'
  end

  on host, "#{cmd}"

end

# Chkconfig is not cross platform, though symlinks in /etc/rc* are, I believe
step 'Confirm Removal of Processes from start up'
hosts.each do |host|
  processes.each do |process|
    on host, " ! grep -Rl #{process} /etc/rc*"
  end
end
