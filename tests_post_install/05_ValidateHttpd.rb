# Validate HTTPD Functionality
# Accepts hash of parsed config file as arg
class ValidateHttpd
  attr_accessor :config, :fail_flag 
  def initialize(config)
    self.config    = config
    self.fail_flag = 0

    os=""
    host=""
    pmaster=""
    usr_home=ENV['HOME']

    @config.host_list.each do |host, os|
      if /^PMASTER/ =~ os then         # Detect Puppet Master node
        pmaster = host
      end
    end


    # Start HTTPD
    test_name="Service Start HTTPD on Puppet Master"
    BeginTest.new(pmaster, test_name)
    runner = RemoteExec.new(pmaster)
    result = runner.do_remote("service edp-httpd start")
    @fail_flag+=result.exit_code
    ChkResult.new(pmaster, test_name, result.stdout, result.stderr, result.exit_code)

    # Check for HTTPD on PMASTER
    test_name="Connect to HTTPD server on Puppet Master"
    tmp_result=0
    BeginTest.new(pmaster, test_name)
      begin  
        if ( Net::HTTP.get "#{pmaster}", '*', '80' )
          tmp_result+=0
        else
          tmp_result+=1
        end
      rescue Exception => se
         puts "Got socket error (#{se.type}): #{se}"
      end
    @fail_flag+=tmp_result
    ChkResult.new(pmaster, test_name, nil, nil, @fail_flag)
    #ChkResult.new(pmaster, test_name, result.stdout, result.stderr, result.exit_code)
  end
end
