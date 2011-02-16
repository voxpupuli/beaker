def run_the_tests(log,options, config)
  Log.debug "Executing tests in #{options[:tests].join(', ')}"
  options[:tests].each do |root|
    Log.debug nil, '=' * 78, nil, "Running tests from #{root}"
    run_tests_under(log, config, options, root)
  end
end

def run_tests_under(log, config, options, root)
  summary = []
  suite = TestSuite.new(root, :random => options[:random])
  Log.notify "Using random seed #{suite.random_seed}" if suite.random_seed
  suite.test_files.each do |test_file|
    Log.debug "", "", "#{test_file} executing..."
    result = TestWrapper.new(config, options, test_file).run_test
    Log.notify "#{test_file} #{result.test_status}ed"
    log.record_result(test_file, result)
  end
end
