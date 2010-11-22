# Build list of tests
# Accecpt test dir as arg
# Return test_list object

class TestList
  attr_accessor :test_list
  def initialize(test_dir_or_file)
    if File.directory?(test_dir_or_file) then
      puts "Detectd dir"
      self.test_list = read_dir(test_dir_or_file)
    else
      puts "Detectd file"
      self.test_list = read_file(test_dir_or_file)
    end
  end

	def each
  	self.test_list.each {|i| yield i}
  end

  # read testdir, find tests
  def read_dir(testdir)
    list = []
    puts "Looking for tests in #{testdir}"
    list = Dir.entries(testdir)
    list.each do |test|
        next if test =~ /^\W/    # skip .hiddens and such
        puts "Found test test"
        require (File.join(testdir,test))
    end
    return list
  end

  def read_file(testfile)
    test=""
    list=[]
    require testfile  # testdir is test file in this case
    test = $1 if /\S+\/(\S+)$/ =~ testfile
    list << test
    return list
  end
end
