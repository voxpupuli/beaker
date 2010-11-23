def prep_nodes(config)
  usr_home=ENV['HOME']
  fail_flag=0

  # 1: SCP remote_exec code to all nodes
	test_name="Copy remote executables to all hosts"
  config.each_key do|host|
	  BeginTest.new(host, test_name)
    scper = ScpFile.new(host)
    result = scper.do_scp("#{$work_dir}/remote.tgz", "/root")
    ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)
		fail_flag+=result.exit_code
  end

  # Execute remote command  on each node, regardless of role
	test_name="Untar remote executables to all hosts"
  config.each_key do|host|
    BeginTest.new(host, test_name)
    runner = RemoteExec.new(host)
    result = runner.do_remote("tar xzf remote.tgz")
    ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)
    fail_flag+=result.exit_code
  end
  return fail_flag
end
