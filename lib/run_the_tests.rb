def run_the_tests(options, config)
  test_summary=[]
  options[:tests].each do |root|
    puts nil, '=' * 78, nil, "Running tests from #{root}"
    test_summary += run_tests_under(config, options, root)
  end
  test_summary
end

def run_tests_under(config, options, root)
  summary = []
  suite = TestSuite.new(root, :random => options[:random])
  puts "Using random seed #{suite.random_seed}" if suite.random_seed
  suite.test_files.each do |test_file|
    puts "", "", "#{test_file} executing..."
    result = TestWrapper.new(config, options, test_file).run_test
    puts "#{test_file} #{result.test_status}ed"
    summary << [test_file, result]
  end
  return summary
end
