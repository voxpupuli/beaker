require 'simplecov'
require 'beaker'
require 'fakefs/spec_helpers'
require 'mocks'
require 'helpers'
require 'matchers'
require 'mock_compute_client'
require 'mock_network_client'
require 'mock_fission'
require 'mock_vsphere'
require 'mock_vsphere_helper'

require 'rspec/its'

RSpec.configure do |config|
  config.include FakeFS::SpecHelpers
  config.include TestFileHelpers
  config.include HostHelpers
end
