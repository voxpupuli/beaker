# Validate Dashboard Functionality
# Check for running dashboard on DASHBORD Host

step "Connect to Dashboard"
BeginTest.new(dashboard, step_name)
tmp_result = begin  
    Net::HTTP.get(dashboard, '*', '3000')
  rescue Exception => se
    puts "Got socket error (#{se.class}): #{se}"
  end
@fail_flag += 1 unless tmp_result
Result.ad_hoc(dashboard, nil, @fail_flag).log(step_name)
