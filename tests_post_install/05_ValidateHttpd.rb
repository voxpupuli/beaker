# Validate HTTPD Functionality
# Accepts hash of parsed config file as arg
class ValidateHttpd
  attr_accessor :config, :fail_flag 
  def initialize(config)
    self.config    = config
    self.fail_flag = 0

    host=""
    role=""
    usr_home=ENV['HOME']

    # Start HTTPD
    test_name="Service Start HTTPD on Puppet Master"
    # Search all hosts...
    @config.each_key do|host|
      # for the role 'master'
      @config[host]['roles'].each do|role|
        if /master/ =~ role then             # If the host is puppet master
          BeginTest.new(host, test_name)
			    runner = RemoteExec.new(host)
					result = runner.do_remote("service edp-httpd start")
					@fail_flag+=result.exit_code
          ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)
        end
      end
    end

    # Check for HTTPD on PMASTER hosts
    test_name="Connect to HTTPD server on Puppet Master"
    tmp_result=0
    # Search all hosts...
    @config.each_key do|host|
      # for the role 'master'
      @config[host]['roles'].each do|role|
        if /master/ =~ role then             # If the host is puppet master
          BeginTest.new(host, test_name)
          begin  
            if ( Net::HTTP.get "#{host}", '*', '80' )
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
