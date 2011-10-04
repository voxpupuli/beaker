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
  on(host, "#{config['puppetbindir']}/puppet-module version") do
    assert_match(/#{version['VERSION']['puppet_module_ver']}/, stdout, "Incorrect Puppet Module tool version detected on #{host} ")
  end
end

step "Check Ruby Gem version"
hosts.each do |host|
  on(host, "#{config['puppetbindir']}/gem --version") do
    assert_match(/#{version['VERSION']['gem_ver']}/, stdout, "Incorrect gem version detected on #{host} ")
  end
end

step "Check Facter version"
hosts.each do |host|
  on(host, "#{config['puppetbindir']}/facter --version") do
    assert_match(/#{version['VERSION']['facter_ver']}/, stdout.chomp, "Incorrect Facter version detected on #{host}")
  end
end

step "Check Puppet version"
hosts.each do |host|
  on(host, "#{config['puppetbindir']}/puppet --version") do
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
