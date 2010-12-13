# Validate HTTPD Functionality

# Start HTTPD
test_name="Service Start HTTPD on Puppet Master"

BeginTest.new(master, test_name)
runner = RemoteExec.new(master)
result = runner.do_remote("service pe-httpd start")
@fail_flag+=result.exit_code
result.log(test_name)

# Check for running HTTPD on PMASTER hosts
test_name="Connect to HTTPD server on Puppet Master"
BeginTest.new(master, test_name)
begin  
  tmp_result = Net::HTTP.get("#{master}", '*', '80') ? 0 : 1
rescue Exception => se
  puts "Got socket error (#{se.class}): #{se}"
end
@fail_flag+=tmp_result
Action::Result.ad_hoc(master, nil, @fail_flag).log(test_name)
