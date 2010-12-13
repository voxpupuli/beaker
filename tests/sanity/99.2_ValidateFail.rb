# Validate Failed Test

test_name="Validate Failed Test"
hosts.each do |host|
  BeginTest.new(host, test_name)
  runner = RemoteExec.new(host)
  result = runner.do_remote("foo command")
  @fail_flag+=result.exit_code
  result.log(test_name)
end

