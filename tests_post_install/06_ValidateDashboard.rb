# Validate Dashboard Functionality
# Accepts hash of parsed config file as arg
class ValidateDashboard
  attr_accessor :config, :fail_flag 
  def initialize(config)
    self.config    = config
    self.fail_flag = 0

    os=""
    host=""
    dashboard=""
    usr_home=ENV['HOME']

    @config.host_list.each do |host, os|
      if /^PMASTER/ =~ os then         # Detect Dashboard host
        dashboard=host
        puts "#{dashboard}"
      end
    end

    # Check for running dashboard on DASHBORD Host
    test_name="Connect to Dashboard on #{dashboard}"
    tmp_result=0
    BeginTest.new(dashboard, test_name)
      begin  
        if ( Net::HTTP.get "#{dashboard}", '*', '3000' )
          tmp_result+=0
        else
          tmp_result+=1
        end
      rescue Exception => se
         puts "Got socket error (#{se.type}): #{se}"
      end
    @fail_flag+=tmp_result
    ChkResult.new(dashboard, test_name, nil, nil, @fail_flag)
  end
end
