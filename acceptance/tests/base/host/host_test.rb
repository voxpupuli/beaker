require "helpers/test_helper"

test_name "confirm host object behave correctly"

step "#port_open? : can determine if a port is open on hosts"
hosts.each do |host|
  logger.debug "port 22 (ssh) should be open on #{host}"
  assert_equal(true, host.port_open?(22), "port 22 on #{host} should be open")
  logger.debug "port 65535 should be closed on #{host}"
  assert_equal(false, host.port_open?(65535), "port 65535 on #{host} should be closed")
end

step "#ip : can determine the ip address on hosts"
hosts.each do |host|
  ip = host.ip
  # confirm ip format
  logger.debug("format of #{ip} for #{host} should be correct")
  assert_match(/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/, ip, "#{ip} on #{host} isn't correct format")
end

step "#is_x86_64? : can determine arch on hosts"
hosts.each do |host|
  if host['platform'] =~ /x86_64|_64|amd64|-64/
    assert_equal(true, host.is_x86_64?, "is_x86_64? should be true on #{host}: #{host['platform']}")
  else
    assert_equal(false, host.is_x86_64?, "is_x86_64? should be false on #{host}: #{host['platform']}")
  end
end

step "#get_env_var : can get a specific environment variable"
hosts.each do |host|
  env_prefix = 'BEAKER' + SecureRandom.hex(4).upcase
  env_param1 = "#{env_prefix}_p1"
  env_value1 = "#{env_prefix}_v1"

  host.clear_env_var(env_param1)
  host.add_env_var(env_param1,env_value1)

  val = host.get_env_var(env_param1)

  assert_match(/^#{env_param1}=#{env_value1}$/, val, "get_env_var can get a specific environment variable")
end

step "#get_env_var : should not match a partial env key name"
hosts.each do |host|
  env_id = 'BEAKER' + SecureRandom.hex(4).upcase
  # Used as a prefix
  env_param1 = "#{env_id}_pre"
  env_value1 = "#{env_id}_pre"
  # Used as a suffix
  env_param2 = "suf_#{env_id}"
  env_value2 = "suf_#{env_id}"
  # Used as a infix
  env_param3 = "in_#{env_id}_in"
  env_value3 = "in_#{env_id}_in"

  host.clear_env_var(env_param1)
  host.clear_env_var(env_param2)
  host.clear_env_var(env_param3)
  host.add_env_var(env_param1,env_value1)
  host.add_env_var(env_param1,env_value2)
  host.add_env_var(env_param1,env_value3)

  val = host.get_env_var(env_id)
  assert('' == val,'get_env_var should not match a partial env key name')
end

step "#get_env_var : should not return a match from a key\'s value"
hosts.each do |host|
  env_prefix = 'BEAKER' + SecureRandom.hex(4).upcase
  env_param1 = "#{env_prefix}_p1"
  env_value1 = "#{env_prefix}_v1"

  host.clear_env_var(env_param1)
  host.add_env_var(env_param1,env_value1)

  val = host.get_env_var(env_value1)
  assert('' == val,'get_env_var should not return a match from a key\'s value')
end

step "#clear_env_var : should only remove the specified key"
hosts.each do |host|
  # Note - Must depend on `SecureRandom.hex(4)` creating a unique key as unable to depend on the function under test `clear_env_var`
  env_id = 'BEAKER' + SecureRandom.hex(4).upcase
  # Use env_id as a suffix
  env_param1 = "p1_#{env_id}"
  env_value1 = "v1_#{env_id}"
  # Use env_id as a prefix
  env_param2 = "#{env_id}_p2"
  env_value2 = "#{env_id}_v2"
  # Use env_id a key to delete
  env_param3 = "#{env_id}"
  env_value3 = "#{env_id}"
  
  host.add_env_var(env_param1,env_value1)
  host.add_env_var(env_param2,env_value2)
  host.add_env_var(env_param3,env_value3)

  host.clear_env_var(env_param3)

  val = host.get_env_var(env_param1)
  assert_match(/^#{env_param1}=#{env_value1}$/, val, "#{env_param1} should exist after calling clear_env_var")
  val = host.get_env_var(env_param2)
  assert_match(/^#{env_param2}=#{env_value2}$/, val, "#{env_param2} should exist after calling clear_env_var")
  val = host.get_env_var(env_param3)
  assert('' == val,"#{env_param3} should not exist after calling clear_env_var")
end

step "#add_env_var : can add a unique environment variable"
hosts.each do |host|
  env_id = 'BEAKER' + SecureRandom.hex(4).upcase
  env_param1 = "#{env_id}"
  env_value1 = "#{env_id}"
  # Use env_id as a prefix
  env_param2 = "#{env_id}_pre"
  env_value2 = "#{env_id}_pre"
  # Use env_id as a suffix
  env_param3 = "suf_#{env_id}"
  env_value3 = "suf_#{env_id}"

  host.clear_env_var(env_param1)
  host.clear_env_var(env_param2)
  host.clear_env_var(env_param3)
  host.add_env_var(env_param1,env_value1)
  host.add_env_var(env_param2,env_value2)
  host.add_env_var(env_param3,env_value3)

  val = host.get_env_var(env_param1)
  assert_match(/^#{env_param1}=#{env_value1}$/, val, "#{env_param1} should exist")
  val = host.get_env_var(env_param2)
  assert_match(/^#{env_param2}=#{env_value2}$/, val, "#{env_param2} should exist")
  val = host.get_env_var(env_param3)
  assert_match(/^#{env_param3}=#{env_value3}$/, val, "#{env_param3} should exist")
end

step "#add_env_var : can add an environment variable"
hosts.each do |host|
  host.clear_env_var("test")
  logger.debug("add TEST=1")
  host.add_env_var("TEST", "1")
  logger.debug("add TEST=1 again (shouldn't create duplicate entry)")
  host.add_env_var("TEST", "1")
  logger.debug("add TEST=2")
  host.add_env_var("TEST", "2")
  logger.debug("ensure that TEST env var has correct setting")
  logger.debug("add TEST=3")
  host.add_env_var("TEST", "3")
  logger.debug("ensure that TEST env var has correct setting")
  val = host.get_env_var("TEST")
  assert_match(/TEST=3(;|:)2(;|:)1$/, val, "add_env_var can correctly add env vars")
end

step "#add_env_var : can preserve an environment between ssh connections"
hosts.each do |host|
  host.clear_env_var("TEST")
  logger.debug("add TEST=1")
  host.add_env_var("TEST", "1")
  logger.debug("add TEST=1 again (shouldn't create duplicate entry)")
  host.add_env_var("TEST", "1")
  logger.debug("add TEST=2")
  host.add_env_var("TEST", "2")
  logger.debug("ensure that TEST env var has correct setting")
  logger.debug("add TEST=3")
  host.add_env_var("TEST", "3")
  logger.debug("close the connection")
  host.close
  logger.debug("ensure that TEST env var has correct setting")
  val = host.get_env_var("TEST")
  assert_match(/TEST=3(;|:)2(;|:)1$/, val, "can preserve an environment between ssh connections")
end

step "#delete_env_var : can delete an environment"
hosts.each do |host|
  logger.debug("remove TEST=3")
  host.delete_env_var("TEST", "3")
  val = host.get_env_var("TEST")
  assert_match(/TEST=2(;|:)1$/, val, "delete_env_var can correctly delete part of a chained env var")
  logger.debug("remove TEST=1")
  host.delete_env_var("TEST", "1")
  val = host.get_env_var("TEST")
  assert_match(/TEST=2$/, val, "delete_env_var can correctly delete part of a chained env var")
  logger.debug("remove TEST=2")
  host.delete_env_var("TEST", "2")
  val = host.get_env_var("TEST")
  assert_equal("", val, "delete_env_var fully removes empty env var")
end

step "#mkdir_p : can recursively create a directory structure on a host"
hosts.each do |host|
  #clean up first!
  host.rm_rf("test1")
  #test dir construction
  logger.debug("create test1/test2/test3/test4")
  assert_equal(true, host.mkdir_p("test1/test2/test3/test4"), "can create directory structure")
  logger.debug("should be able to create a file in the new dir")
  on host, host.touch("test1/test2/test3/test4/test.txt", false)
end

step "#do_scp_to : can copy a directory to the host with no ignores"
current_dir = File.dirname(__FILE__)
module_fixture = File.join(current_dir, "../../../fixtures/module")
hosts.each do |host|
  logger.debug("can recursively copy a module over")
  #make sure that we are clean on the test host
  host.rm_rf("module")
  host.do_scp_to(module_fixture, ".", {})
  Dir.mktmpdir do |tmp_dir|
    #grab copy from host
    host.do_scp_from("module", tmp_dir, {})
    #compare to local copy
    local_paths = Dir.glob(File.join(module_fixture, "**/*")).select { |f| File.file?(f) }
    host_paths  = Dir.glob(File.join(File.join(tmp_dir, "module"), "**/*")).select { |f| File.file?(f) }
    #each local file should have a single match on the host
    local_paths.each do |path|
      search_name = path.gsub(/^.*fixtures\//, '') #reduce down to the path that should match
      matched = host_paths.select{ |check| check =~ /#{Regexp.escape(search_name)}$/ }
      assert_equal(1, matched.length, "should have found a single instance of path #{search_name}, found #{matched.length}: \n #{matched}")
      host_paths = host_paths - matched
    end
    assert_equal(0, host_paths.length, "there are extra paths on #{host} (#{host_paths})")
  end
end

step "#do_scp_to with :ignore : can copy a dir to the host, excluding ignored patterns that DO NOT appear in the source absolute path"
current_dir = File.dirname(__FILE__)
module_fixture = File.expand_path(File.join(current_dir, "../../../fixtures/module"))
hosts.each do |host|
  logger.debug("can recursively copy a module over, ignoring some files/dirs")
  #make sure that we are clean on the test host
  host.rm_rf("module")
  host.do_scp_to(module_fixture, ".", {:ignore => ['tests', 'Gemfile']})
  Dir.mktmpdir do |tmp_dir|
    #grab copy from host
    host.do_scp_from("module", tmp_dir, {})
    #compare to local copy
    local_paths = Dir.glob(File.join(module_fixture, "**/*")).select { |f| File.file?(f) }
    host_paths  = Dir.glob(File.join(File.join(tmp_dir, "module"), "**/*")).select { |f| File.file?(f) }
    #each local file should have a single match on the host
    local_paths.each do |path|
      search_name = path.gsub(/^.*fixtures\//, '') #reduce down to the path that should match
      matched = host_paths.select{ |check| check =~ /#{Regexp.escape(search_name)}$/ }
      re =  /((\/|\A)tests(\/|\z))|((\/|\A)Gemfile(\/|\z))/
      if path !~ re
        assert_equal(1, matched.length, "should have found a single instance of path #{search_name}, found #{matched.length}: \n #{matched}")
      else
        assert_equal(0, matched.length, "should have found no instances of path #{search_name}, found #{matched.length}: \n #{matched}")
      end
      host_paths = host_paths - matched
    end
    assert_equal(0, host_paths.length, "there are extra paths on #{host} (#{host_paths})")
  end
end

step "#do_scp_to with :ignore : can copy a dir to the host, excluding ignored patterns that DO appear in the source absolute path"
current_dir = File.dirname(__FILE__)
module_fixture = File.expand_path(File.join(current_dir, "../../../fixtures/module"))
hosts.each do |host|
  logger.debug("can recursively copy a module over, ignoring some sub-files/sub-dirs that also appear in the absolute path")
  #make sure that we are clean on the test host
  host.rm_rf("module")
  host.do_scp_to(module_fixture, ".", {:ignore => ['module', 'Gemfile']})
  Dir.mktmpdir do |tmp_dir|
    #grab copy from host
    host.do_scp_from("module", tmp_dir, {})
    #compare to local copy
    local_paths = Dir.glob(File.join(module_fixture, "**/*")).select { |f| File.file?(f) }
    host_paths  = Dir.glob(File.join(File.join(tmp_dir, "module"), "**/*")).select { |f| File.file?(f) }
    #each local file should have a single match on the host
    local_paths.each do |path|
      search_name = path.gsub(/^.*fixtures\/module\//, '') #reduce down to the path that should match
      matched = host_paths.select{ |check| check =~ /#{Regexp.escape(search_name)}$/ }
      re =  /((\/|\A)module(\/|\z))|((\/|\A)Gemfile(\/|\z))/
      if path.gsub(/^.*module\//, '') !~ re
        assert_equal(1, matched.length, "should have found a single instance of path #{search_name}, found #{matched.length}: \n #{matched}")
      else
        assert_equal(0, matched.length, "should have found no instances of path #{search_name}, found #{matched.length}: \n #{matched}")
      end
      host_paths = host_paths - matched
    end
    assert_equal(0, host_paths.length, "there are extra paths on #{host} (#{host_paths})")
  end
end

step "Ensure scp errors close the ssh connection" do

  step 'Attempt to generate a remote file that does not exist' do

    # This assert relies on the behavior of the net-scp library to
    # raise an error when #channel.on_close is called, which is called by
    # indirectly called by beaker's own SshConnection #close mehod. View
    # the source for further info:
    # https://github.com/net-ssh/net-sacp/blob/master/lib/net/scp.rb
    assert_raises Net::SCP::Error do
      create_remote_file(default, '/tmp/this/path/cannot/possibly/exist.txt', "contents")
    end
  end

  step 'Ensure that a subsequent ssh connection works' do
    # If the ssh connection was left in a dangling state, then this #on call will hang
    on default, 'true'
  end

  step 'Attempt to scp from a resource on the SUT that does not exist' do

    # This assert relies on the behavior of the net-scp library to
    # use the Dir.mkdir method in the #download_start_state method.
    # See the source for further info:
    # https://github.com/net-ssh/net-sacp/blob/master/lib/net/scp/download.rb
    assert_raises Errno::ENOENT do
      scp_from default, '/tmp/path/dne/wtf/bbq', '/tmp/path/dne/wtf/bbq'
    end
  end

  step 'Ensure that a subsequent ssh connection works' do
    # If the ssh connection was left in a dangling state, then this #on call will hang
    on default, 'true'
  end
end

step 'Ensure that a long 128+ character string with UTF-8 characters does not break net-ssh' do
  long_string = 'a' * 128 + "\u06FF"
  on(default, "mkdir /tmp/#{long_string}")
  result = on(default, 'ls /tmp')
  assert(result.stdout.include?(long_string), 'Error in folder creation with long string + UTF-8 characters')

  # remove the folder
  on(default, "rm -rf /tmp/#{long_string}")
  result = on(default, 'ls /tmp')
  assert(!result.stdout.include?(long_string), 'Error in folder deletion with long string + UTF-8 characters')

end

