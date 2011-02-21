def perform_test_setup_steps(log, options, config)
  Log.debug '=' * 78, "Performing test setup steps", ''
  # PE signs certs during install; after/ValidateSignCert is not required.
  # Not all test passes should exec after/*.  Need to another technique
  # for post installer steps.
  # ["setup/early", "setup/#{options[:type]}", "setup/late"].each do |root|
  ["setup/early", "setup/#{options[:type]}"].each do |root|
    run_tests_under(log, config, options.merge({:random => false}), root).each do |test, result|
      unless result.test_status == :pass then
        Log.error "Setup action #{test} failed, exiting..."
        exit 1
      end
    end
  end
end
