source ENV['GEM_SOURCE'] || 'https://rubygems.org'

gemspec

if ENV['BEAKER_HYPERVISOR']
  # vagrant_libvirt -> vagrant
  gem "beaker-#{ENV['BEAKER_HYPERVISOR'].split('_').first}"
end

group :release, optional: true do
  gem 'faraday-retry', '~> 2.1', require: false
  gem 'github_changelog_generator', '~> 1.16.4', require: false
end
