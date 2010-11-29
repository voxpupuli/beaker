def prep_nodes(config)
  usr_home=ENV['HOME']
  fail_flag=0
  master=""

  # Extract Master from config
  config["HOSTS"].each_key do|host|
    config["HOSTS"][host]['roles'].each do |role|
      master=host if /master/ =~ role
    end
  end
  
  # 1: SCP ptest/bin code to all nodes
	test_name="Copy ptest.tgz executables to all hosts"
  config["HOSTS"].each_key do|host|
	  BeginTest.new(host, test_name)
    scper = ScpFile.new(host)
    result = scper.do_scp("#{$work_dir}/ptest.tgz", "/")
    ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)
		fail_flag+=result.exit_code
  end

  # Execute remote command on each node, regardless of role
	test_name="Untar ptest.tgz executables to all hosts"
  config["HOSTS"].each_key do|host|
    BeginTest.new(host, test_name)
    runner = RemoteExec.new(host)
    result = runner.do_remote("cd / && tar xzf ptest.tgz")
    ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)
    fail_flag+=result.exit_code
  end

  # 1: SCP puppet code to master
	test_name="Copy puppet.tgz code to Master"
	BeginTest.new(master, test_name)
  scper = ScpFile.new(master)
  result = scper.do_scp("#{$work_dir}/puppet.tgz", "/etc/puppetlabs")
  ChkResult.new(master, test_name, result.stdout, result.stderr, result.exit_code)
  fail_flag+=result.exit_code

  # untar puppet code on master
	test_name="Untar Puppet code on Master"
  BeginTest.new(master, test_name)
  runner = RemoteExec.new(master)
  result = runner.do_remote("cd /etc/puppetlabs && tar xzf puppet.tgz")
  ChkResult.new(master, test_name, result.stdout, result.stderr, result.exit_code)
  fail_flag+=result.exit_code

  return fail_flag

end
