# Build list of tests
# Accecpt test dir as arg
# Return test_list object

class FindTests
  attr_accessor :testdir
  def initialize(testdir)
      self.testdir = testdir
  end

  class TestList
    attr_accessor :test_list
    def initialize(test_list=[])
      self.test_list = test_list
    end
  end

  # read testdir, find tests
  def read_dir
    test_list = TestList.new
    puts "Looking for tests in #{$work_dir}/#{testdir}"
    test_list = Dir.entries "#{$work_dir}/#{testdir}"
    test_list.each do |test|
        next if test =~ /^\W/    # skip .hiddens and such
        puts "Found test #{test}"
        require "#{$work_dir}/#{testdir}/#{test}"
    end
    return test_list
  end
end
