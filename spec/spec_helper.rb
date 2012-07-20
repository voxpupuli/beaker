require 'puppet_acceptance'
require 'fakefs/spec_helpers'

module TestFileHelpers
  def create_files file_array
    file_array.each do |f|
      FileUtils.mkdir_p File.dirname(f)
      FileUtils.touch f
    end
  end
end

RSpec.configure do |config|
  config.include FakeFS::SpecHelpers
  config.include TestFileHelpers
end
