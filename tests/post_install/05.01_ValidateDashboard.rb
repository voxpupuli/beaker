# Validate Dashboard Functionality
# Accepts hash of parsed config file as arg

# Check for running dashboard on DASHBORD Host

test_name="Connect to Dashboard"
BeginTest.new(dashboard, test_name)
tmp_result = begin  
    Net::HTTP.get(dashboard, '*', '3000')
  rescue Exception => se
    puts "Got socket error (#{se.class}): #{se}"
  end
@fail_flag += 1 unless tmp_result
Action::Result.ad_hoc(dashboard, nil, @fail_flag).log(test_name)
