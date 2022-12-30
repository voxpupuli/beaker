begin
  require 'simplecov'
  require 'simplecov-console'
  require 'codecov'
rescue LoadError
else
  SimpleCov.start do
    track_files 'lib/**/*.rb'

    add_filter '/spec'

    enable_coverage :branch

    # do not track vendored files
    add_filter '/vendor'
    add_filter '/.vendor'
  end

  SimpleCov.formatters = [
    SimpleCov::Formatter::Console,
    SimpleCov::Formatter::Codecov,
  ]
end

require 'beaker'
require 'fakefs/spec_helpers'
require 'mocks'
require 'helpers'
require 'matchers'
require 'rspec/its'

RSpec.configure do |config|
  config.include FakeFS::SpecHelpers
  config.include TestFileHelpers
  config.include HostHelpers
end
