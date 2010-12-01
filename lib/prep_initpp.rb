def prep_initpp(host, entry, path)
  fail_flag=0

  # Rewrite the init.pp file with a single class to test
  # eg: class puppet_system_test { include file }
	test_name="Write new init.pp"
  BeginTest.new(host, test_name)
  runner = RemoteExec.new(host)
  result = runner.do_remote("echo class puppet_system_test \{ include #{entry} \} > #{path}/init.pp")
  ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)
  fail_flag+=result.exit_code

  return fail_flag

end
