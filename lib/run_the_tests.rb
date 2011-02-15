def run_the_tests(log,options, config)
  options[:tests].each do |root|
    puts nil, '=' * 78, nil, "Running tests from #{root}"
		run_tests_under(log, config, options, root)
  end
end

def run_tests_under(log, config, options, root)
  (Dir[File.join(root, "**/*.rb")] + [root]).select { |f| File.file?(f) }.each do |name|
    puts "", "", "#{name} executing..."
    result = TestWrapper.new(config,options,name).run_test
    puts "#{name} #{result.test_status}ed"
		log.record_result(name, result)
  end
end

