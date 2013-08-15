require "rspec/expectations"
require "beaker-rspec"

RSpec.configure do |config|
  # System specific config
  config.add_setting :beaker_config

  config.beaker_config = 'sample.cfg'

  config.include BeakerRSpec

  config.before(:all) do
    setup(RSpec.configuration.beaker_config)
  end

  config.after(:all) do
    cleanup
  end

end
