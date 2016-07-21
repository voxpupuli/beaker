test_name "validate host stubbing behavior"

def get_hosts_file(host)
  if host['platform'] =~ /win/
    hosts_file = "C:\\\\Windows\\\\System32\\\\Drivers\\\\etc\\\\hosts"
  else
    hosts_file = '/etc/hosts'
  end
  return hosts_file
end

step 'verify stub_host_on' do
  step 'should add entry to hosts file' do
    hosts.each do |host|
      stub_hosts_on(host, { 'foo' => '1.1.1.1' }, { 'foo' => [ 'bar', 'baz' ] })
      hosts_file = get_hosts_file(host)
      result = on host, "cat #{hosts_file}"
      assert_match %r{foo}, result.stdout
    end
  end

  step 'stubbed value should be available for other steps in the test' do
    hosts.each do |host|
      hosts_file = get_hosts_file(host)
      result = on host, "cat #{hosts_file}"
      assert_match %r{foo}, result.stdout
    end
  end
end

step 'verify with_stub_host_on' do
  step 'should add entry to hosts file' do
    hosts.each do |host|
      hosts_file = get_hosts_file(host)
      result = with_host_stubbed_on(host, { 'sleepy' => '1.1.1.2' }, { 'sleepy' => [ 'grumpy', 'dopey' ] }) { on host, "cat #{hosts_file}" }
      assert_match %r{sleepy}, result.stdout
    end
  end

  step 'stubbed value should be reverted after the execution of the block' do
    hosts.each do |host|
      hosts_file = get_hosts_file(host)
      result = on host, "cat #{hosts_file}"
      assert_no_match %r{sleepy}, result.stdout
    end
  end
end
