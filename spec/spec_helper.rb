require 'rbconfig'
ruby_conf = defined?(RbConfig) ? RbConfig::CONFIG : Config::CONFIG

unless ruby_conf['MAJOR'].to_i == 1 && ruby_conf['MINOR'].to_i < 9
  require 'simplecov'
end

require 'beaker'
require 'fakefs/spec_helpers'
require 'mocks'
require 'helpers'
require 'matchers'
require 'mock_fission'
require 'mock_vsphere'
require 'mock_vsphere_helper'

RSpec.configure do |config|
  config.include FakeFS::SpecHelpers
  config.include TestFileHelpers
  config.include HostHelpers
end
