require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:beaker) do |c|
  c.pattern = "spec/acceptance/**/*_spec.rb"
end
