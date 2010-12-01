def prep_initpp(host, entry, path)
  fail_flag=0

  # Rewrite the init.pp file with an additional class to test
  # eg: class puppet_system_test { 
  #  include group
  #  include user
  #}
	test_name="Append new system_test_class to init.pp"
  BeginTest.new(host, test_name)
  runner = RemoteExec.new(host)
  result = runner.do_remote("cd #{path} && head -n -1 init.pp > tmp_init.pp && echo include #{entry} >> tmp_init.pp && echo \} >> tmp_init.pp && mv -f tmp_init.pp init.pp")
  ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)
  fail_flag+=result.exit_code

  return fail_flag

end
