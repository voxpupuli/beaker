# Validate Positive Test

test_name="Validate Positive Test"

hosts.each do |host|
  puts "Host Names: #{host}"
  BeginTest.new(host, test_name)
  runner = RemoteExec.new(host)
  result = runner.do_remote("uname -a")
  @fail_flag+=result.exit_code
  result.log(test_name)
end

