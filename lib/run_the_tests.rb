def run_the_tests(log,options, config)
  Log.debug "Executing tests in #{options[:tests].join(', ')}"
  options[:tests].each do |root|
    Log.debug nil, '=' * 78, nil, "Running tests from #{root}"
    run_tests_under(log, config, options, root)
  end
end

def run_tests_under(log, config, options, root)
  (Dir[File.join(root, "**/*.rb")] + [root]).select { |f| File.file?(f) }.each do |name|
    Log.debug "", "", "#{name} executing..."
    result = TestWrapper.new(config,options,name).run_test
    Log.notify "#{name} #{result.test_status}ed"
    log.record_result(name, result)
  end
end

