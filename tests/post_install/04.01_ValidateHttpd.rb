# Validate HTTPD Functionality

step "Service Start HTTPD on Puppet Master"
on master,"service pe-httpd start"

step "Connect to HTTPD server on Puppet Master"
tmp_result = begin  
    Net::HTTP.get("#{master}", '*', '80')
  rescue Exception => se
    puts "Got socket error (#{se.class}): #{se}"
  end
@fail_flag += 1 unless tmp_result
Result.ad_hoc(master, nil, @fail_flag).log(step_name)
