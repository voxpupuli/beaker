# Check Result of Test
# Provides standard output for logging
class ChkResult
  attr_accessor :host, :test_name, :test_stdout, :test_stderr, :test_exitcode
  def initialize(host, test_name, test_stdout, test_stderr, test_exitcode)
      self.host = host
      self.test_name = test_name 
      self.test_stdout = test_stdout
      self.test_stderr = test_stderr
      self.test_exitcode = test_exitcode
     
      puts "OUTPUT (stdout, stderr, exitcode):"
      puts @test_stdout
      puts @test_stderr
      puts @test_exitcode
      if (@test_exitcode == 0)
        puts "RESULT*** TEST:#{test_name} STATUS:PASSED on HOST:#{host}"
      else
        puts "RESULT*** TEST:#{test_name} STATUS:FAILED on HOST:#{host}"
      end
  end
end
