test_name "Verify correct versions of installed PE code"

step "Check for presence of pe_version file"
hosts.each do |host|
  on(host, "test -f /opt/puppet/pe_version") do
    assert_equal(0, exit_code)
  end
end

step "Check Puppet Module version"
hosts.each do |host|
  next if host['platform'].include?('solaris')
  on(host, "#{host['puppetbindir']}/puppet-module version") do
    assert_match(/#{version['VERSION']['puppet_module_ver']}/, stdout, "Incorrect Puppet Module tool version detected on #{host} ")
  end
end

step "Check Ruby Gem version"
hosts.each do |host|
  on(host, "#{host['puppetbindir']}/gem --version") do
    assert_match(/#{version['VERSION']['gem_ver']}/, stdout, "Incorrect gem version detected on #{host} ")
  end
end

step "Check Facter version"
hosts.each do |host|
  on(host, "#{host['puppetbindir']}/facter --version") do
    assert_match(/#{version['VERSION']['facter_ver']}/, stdout.chomp, "Incorrect Facter version detected on #{host}")
  end
end

step "Check Puppet version"
hosts.each do |host|
  on(host, "#{host['puppetbindir']}/puppet --version") do
    assert_match(/#{version['VERSION']['puppet_ver']}/, stdout, "Incorrect Puppet version detected on #{host}")
  end
end

step "Check Rack version"
hosts.each do |host|
  next if host['roles'].include? 'agent'

  if host['platform'] =~ /debian|ubuntu/
    on(host, 'dpkg -l pe-rack') do
      assert_match(/#{version['VERSION']['rack_ver']}/, stdout, "Incorrect Rack version detected on #{host}")
    end
  else
    on(host, 'rpm -q pe-rubygem-rack') do
      assert_match(/#{version['VERSION']['rack_ver']}/, stdout, "Incorrect Rack version detected on #{host}")
    end
  end
end

step "Check version of Ruby Augeas bindings"
hosts.each do |host|
  next unless host['roles'].include? 'agent'
  next if host['platform'] =~ /solaris/
  cmd = ''

  if host['platform'] =~ /debian|ubuntu/
    cmd = 'dpkg -l pe-ruby-augeas'
  else
    cmd = 'rpm -q pe-ruby-augeas'
  end

  on(host, cmd) do
    assert_match(/#{version['VERSION']['ruby_augeas_ver']}/, stdout, "Incorrect Ruby Augeas Bindings version detected on #{host}")
  end
end

# This logic is for Ruby Gems that are packaged with be on the master/dash
%w(activerecord activesupport).each do |pkg|
  step "Check version of #{pkg}"
  hosts.each do |host|
    next unless host['roles'].include?('master') || host['roles'].include?('dashboard')
    cmd = ''

    if host['platform'] =~ /debian|ubuntu/
      cmd = "dpkg -l pe-#{pkg}"
    else
      cmd = "rpm -q pe-rubygem-#{pkg}"
    end

    on(host, cmd) do
      assert_match(/#{version['VERSION']["#{pkg}_ver"]}/, stdout, "Incorrect #{pkg} version detected on #{host}")
    end
  end
end


hosts.each do |host|
  next unless host['roles'].include?('dashboard')
  cmd = ''

  if host['platform'] =~ /debian|ubuntu/
    cmd = "dpkg -l"
  else
    cmd = "rpm -q"
  end

  on host, "#{cmd} pe-puppet-dashboard" do
    assert_match(/#{version['VERSION']['dashboard_ver']}/, stdout,
                 "Incorrect version of dashboard on #{host}")
  end
end

hosts.each do |host|
  next unless host['platform'] =~ /solaris/
  next unless host['platform'] =~ /windows/

  config['pe_ver'] =~ /^(\d\.\d\.\d)/
  version_string = %r{$1}

  if host['platform'] =~ /debian|ubuntu/
    cmd = "dpkg -l"
  else
    cmd = "rpm -q"
  end

  on host, "#{cmd} pe-puppet-enterprise-release" do
    assert_match version_string, stdout, "This is not the correct release version"
  end
end

