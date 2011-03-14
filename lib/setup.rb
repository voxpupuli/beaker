def perform_test_setup_steps(log, options, config)
  Log.debug '=' * 78, "Performing test setup steps", ''
  # PE signs certs during install; after/ValidateSignCert is not required.
  # Not all test passes should exec after/*.  Need to another technique
  # for post installer steps.
  # ["setup/early", "setup/#{options[:type]}", "setup/late"].each do |root|
  ["setup/early", "setup/#{options[:type]}"].each do |root|
    pass = options.merge({ :random => false, :tests => root })
    suite = TestSuite.new(log, pass, config)
    suite.run.each do |test, result|
      unless result.test_status == :pass then
        Log.error "Setup action #{test} failed, exiting..."
        exit 1
      end
    end
  end
end
