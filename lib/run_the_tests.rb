def run_the_tests(log,options, config)
  options[:tests].each do |root|
    run_tests_under(log, config, options, root)
  end
end

def run_tests_under(log, config, options, root)
  summary = []
  suite = TestSuite.new(root, :random => options[:random])
  Log.notify "Using random seed #{suite.random_seed}" if suite.random_seed
  suite.test_files.each do |test_file|
    Log.notify
    result = TestWrapper.new(config, options, test_file).run_test
    status_color = case result.test_status
                   when :pass
                     Log::GREEN
                   when :fail
                     Log::RED
                   when :error
                     Log::YELLOW
                   end
    Log.notify "#{status_color}#{test_file} #{result.test_status}ed#{Log::NORMAL}"
    log.record_result(test_file, result)
  end
end
