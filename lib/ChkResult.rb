# Check Result of Test
# Standardized output of test results
class ChkResult
  attr_accessor :host, :test_name, :test_status, :test_output
  def initialize(host, test_name, test_status, test_output)
      self.host = host
      self.test_name = test_name 
      self.test_status = test_status 
      self.test_output = test_output
     
      puts "OUTPUT*** TEST:#{test_name}"
      puts @test_output
      puts
      if (@test_status == 0)
        puts "RESULT*** TEST:#{test_name} STATUS:PASSED on HOST:#{host}"
      else
        puts "RESULT*** TEST:#{test_name} STATUS:FAILED on HOST:#{host}"
      end
  end
end
