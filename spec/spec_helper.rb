require "rspec/expectations"
require "beaker-rspec"

RSpec.configure do |config|
  # System specific config
  config.include BeakerRSpec

  config.before(:all) do
    setup(['--hosts', 'sample.cfg'])
    provision
    validate
  end

  config.after(:all) do
    cleanup
  end

end
