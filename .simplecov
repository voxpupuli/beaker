SimpleCov.configure do
  add_filter 'spec/'
  add_filter 'vendor/'
  add_filter do |file|
    file.lines_of_code < 10
  end
  add_group 'Answers', '/answers/'
  add_group 'DSL', '/dsl/'
  add_group 'Host', '/host/'
  add_group 'Hypervisors', '/hypervisor/'
  add_group 'Options', '/options/'
  add_group 'Shared', '/shared/'
end

SimpleCov.start if ENV['BEAKER_COVERAGE']
