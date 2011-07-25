test_name "Verify correct versions of installed PE code"

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
