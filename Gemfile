source ENV['GEM_SOURCE'] || 'https://rubygems.org'

gemspec

if ENV['BEAKER_HYPERVISOR']
  # vagrant_libvirt -> vagrant
  gem "beaker-#{ENV['BEAKER_HYPERVISOR'].split('_').first}"
end

group :release do
  gem 'faraday-retry', require: false
  gem 'github_changelog_generator', require: false
end
