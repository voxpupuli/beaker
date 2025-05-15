require 'beaker'
require 'fakefs/spec_helpers'
require 'mocks'
require 'helpers'
require 'matchers'

RSpec.configure do |config|
  config.include FakeFS::SpecHelpers
  config.include TestFileHelpers
  config.include HostHelpers
end
