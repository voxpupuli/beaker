source ENV['GEM_SOURCE'] || 'https://rubygems.org'

gemspec

if ENV['BEAKER_HYPERVISOR']
  # vagrant_libvirt -> vagrant
  gem "beaker-#{ENV['BEAKER_HYPERVISOR'].split('_').first}"
end

group :release, optional: true do
  gem 'faraday-retry', '~> 2.1', require: false
  # fix from smortex to properly process commits that exist in multiple branches
  # gem 'github_changelog_generator', github: 'smortex/github-changelog-generator', branch: 'avoid-processing-a-single-commit-multiple-time', require: false
  gem 'github_changelog_generator', '~> 1.16.4', require: false
end
