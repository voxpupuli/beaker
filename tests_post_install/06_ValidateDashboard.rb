# Validate Dashboard Functionality
# Accepts hash of parsed config file as arg
class ValidateDashboard
  attr_accessor :config, :fail_flag 
  def initialize(config)
    self.config    = config
    self.fail_flag = 0

    host=""
    role=""
    usr_home=ENV['HOME']

    # Check for running dashboard on DASHBORD Host
    tmp_result=0
    test_name="Connect to Dashboard"
    # Seach each host
    @config.each_key do|host|
      # for role 'dashboard'
      @config[host]['roles'].each do|role|
        if /dashboard/ =~ role then             # found dashboard host
          BeginTest.new(host, test_name)
          begin  
            if ( Net::HTTP.get host, '*', '3000' )
              tmp_result+=0
            else
              tmp_result+=1
            end
          rescue Exception => se
            puts "Got socket error (#{se.type}): #{se}"
          end
          @fail_flag+=tmp_result
          ChkResult.new(host, test_name, nil, nil, @fail_flag)
        end
      end
    end
  end
end
