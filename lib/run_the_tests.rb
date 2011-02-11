def run_the_tests(options, config)
  test_summary={}           # hash to save test results
  options[:tests].each do |root|
    puts nil, '=' * 78, nil, "Running tests from #{root}"
    test_summary.merge! run_tests_under(config, options, root)
  end
  test_summary
end

def run_tests_under(config, options, root)
  summary = {}
  (Dir[File.join(root, "**/*.rb")] + [root]).select { |f| File.file?(f) }.each do |name|
    puts "", "", "#{name} executing..."
    result = TestWrapper.new(config,options,name).run_test
    puts "#{name} returned: #{result.fail_flag}"
    summary[name] = result.fail_flag
  end
  return summary
end

