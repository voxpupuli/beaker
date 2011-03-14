def perform_test_setup_steps(options, config)
  Log.debug '=' * 78, "Performing test setup steps", ''
  # PE signs certs during install; after/ValidateSignCert is not required.
  # Not all test passes should exec after/*.  Need to another technique
  # for post installer steps.
  # ["setup/early", "setup/#{options[:type]}", "setup/late"].each do |root|
  pass = options.merge({ :random => false,
                         :tests  => ["setup/early", "setup/#{options[:type]}"] })
  suite = TestSuite.new(pass, config).new
  suite.run
  unless suite.success? then
    Log.error "Setup suite failed, exiting..."
    exit 1
  end
end
