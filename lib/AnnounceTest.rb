# Accounce the beginning of a test case
# Provides standard output for logging
class BeginTest
  attr_accessor :host, :test_name
  def initialize(host, test_name)
      self.host = host
      self.test_name = test_name
      puts "Running \"#{test_name}\" on #{host}"
  end
end
