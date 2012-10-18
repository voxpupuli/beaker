require 'puppet_acceptance'
require 'fakefs/spec_helpers'
require 'mocks_and_helpers'

RSpec.configure do |config|
  config.include FakeFS::SpecHelpers
  config.include TestFileHelpers
end
