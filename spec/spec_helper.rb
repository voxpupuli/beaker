require 'beaker'
require 'fakefs/spec_helpers'
require 'mocks'
require 'helpers'
require 'matchers'

RSpec.configure do |config|
  config.include FakeFS::SpecHelpers
  config.include TestFileHelpers
  config.include HostHelpers
  # Use the GitHub Annotations formatter for CI
  if ENV['GITHUB_ACTIONS'] == 'true'
    begin
      require 'rspec/github'
    rescue LoadError
      # This is a development dependency, but beaker plugins reuse this and may
      # not specify it
    else
      config.add_formatter RSpec::Github::Formatter
    end
  end
end
