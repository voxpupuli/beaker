test_name 'Ensure the Unistaller works against a basic Puppet Enterprise Install'

# NOTE: we are not currently testing for log or run dirs!
directories =   [ '/opt/puppet', '/var/opt/lib/pe-puppet', '/var/opt/lib/pe-puppetmaster',
                  '/var/opt/cache/pe-puppet-dashboard', '/var/opt/puppet' ]

processes =     [ 'puppetagent', 'pe-puppet', 'pe-puppet-agent', 'pe-mcollective',
                  'pe-httpd', 'pe-activemq', 'pe-memcached', 'pe-dashboard-workers' ]

users_groups =  [ 'pe-memcached', 'pe-apache', 'pe-puppet', 'puppet-dashboard',
                  'pe-activemq', 'peadmin', 'pe-mco' ]

symlinks =      [ 'puppet', 'facter', 'puppet-module', 'mco', 'pe-man' ]

# NOTE: which packages are installed on deb, el, sles, sol?
packages =      /^pe-.*$/

step 'Uninstall!'
hosts.each do |host|
  on host, "cd /tmp/puppet-enterprise-#{config['pe_ver']}-#{host['platform']}/ " +
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
    on host, " ! [[ -f /etc/init.d/#{process}"
  end

  symlinks.each do |sym|
    on host, " ! [[ -f /usr/local/bin/#{sym}"
  end
end

step 'Confirm Removal of Users and Groups'
hosts.each do |host|
  users_groups.each do |usr_grp|
    on host, " ! cat /etc/passwd | grep #{usr_grp}"
    on host, " ! cat /etc/group | grep #{usr_grp}"
  end
end

step 'Confirm Removal of Packages WIP'

step 'Confirm Removal of Processes'
