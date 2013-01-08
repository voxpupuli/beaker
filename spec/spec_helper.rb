require 'rbconfig'
ruby_conf = defined?(RbConfig) ? RbConfig::CONFIG : Config::CONFIG

unless ruby_conf['MAJOR'].to_i == 1 && ruby_conf['MINOR'].to_i < 9
  require 'simplecov'
end

require 'puppet_acceptance'
require 'fakefs/spec_helpers'
require 'mocks_and_helpers'

RSpec.configure do |config|
  config.include FakeFS::SpecHelpers
  config.include TestFileHelpers
end
