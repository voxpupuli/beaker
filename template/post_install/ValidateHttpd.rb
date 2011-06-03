# Validate HTTPD Functionality

step "Service Start HTTPD on Puppet Master"
on master,"service pe-httpd start"

step "Connect to HTTPD server on Puppet Master"
begin
  Net::HTTP.get("#{master}", '*', '80')
rescue Exception => se
  fail_test("Can't connect to master at #{dashboard}, #{se.class}: #{se}")
end

