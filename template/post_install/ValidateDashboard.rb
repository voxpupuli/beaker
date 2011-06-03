# Validate Dashboard Functionality
# Check for running dashboard on DASHBORD Host

step "Connect to Dashboard"
begin
  Net::HTTP.get(dashboard, '*', '3000')
rescue Exception => se
  fail_test("Can't connect to dashboard at #{dashboard}, #{se.class}: #{se}")
end
