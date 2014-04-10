SimpleCov.configure do
  add_filter 'spec/'
  add_filter do |file|
    file.lines_of_code < 10
  end
  add_group 'DSL', '/dsl'
  add_group 'Host', '/host'
  add_group 'Utils' do |file|
    files = %w(cli.rb logger.rb options_parsing.rb test_config.rb utils/)
    files.any? {|f| file.filename =~ Regexp.new( Regexp.quote(f) ) }
  end
  add_group 'Hypervisors', '/hypervisor'
end

SimpleCov.start if ENV['COVERAGE']
