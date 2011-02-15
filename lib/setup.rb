def perform_test_setup_steps(options, config)
  puts '=' * 78, "Performing test setup steps", ''
  # PE signs certs during install; after/ValidateSignCert is not required.
  # Not all test passes should exec after/*.  Need to another technique
  # for post installer steps.
  # ["setup/early", "setup/#{options[:type]}", "setup/late"].each do |root|
  ["setup/early", "setup/#{options[:type]}"].each do |root|
    run_tests_under(config, options.merge({:random => false}), root).each do |test, result|
      unless result == 0 then
        puts "Warn: Setup action #{test} returned non-zero"
        # Installer often returns non-zero upon sucessful install and hence we should warn
        # vs bailing at this stage.
        # exit 1
      end
    end
  end
end
