source ENV['GEM_SOURCE'] || 'https://rubygems.org'

gemspec

# This section of the gemspec is for Puppet CI; it will pull in
# a supported beaker library for testing to overwrite the gemspec if
# a corresponding ENV var is found. Currently, the only supported lib
# is beaker-pe, which can be injected into the dependencies when the
# following ENV vars are defined: BEAKER_PE_PR_AUTHOR,
# BEAKER_PE_PR_COMMIT, BEAKER_PE_PR_REPO_URL. These correspond to the
# ghprb variables ghprbPullAuthorLogin, ghprbActualCommit,
# and ghprbAuthorRepoGitUrl respectively. In the "future", we should
# make this a standard format so we can pull in more than predefined
# variables.

if ENV['BEAKER_PE_PR_REPO_URL']
  lib = ENV['BEAKER_PE_PR_REPO_URL'].match(/\/([^\/]+)\.git$/)[1]
  author = ENV['BEAKER_PE_PR_AUTHOR']
  ref = ENV['BEAKER_PE_PR_COMMIT']
  gem lib, :git => "git@github.com:#{author}/#{lib}.git", :branch => ref
end

group :rubocop do
  gem 'rubocop', '~> 1.12.0'
  gem 'rubocop-performance'
  gem 'rubocop-rake'
  gem 'rubocop-rspec'
end

group :release do
  gem 'github_changelog_generator', require: false
end

group :coverage, optional: ENV['COVERAGE']!='yes' do
  gem 'codecov', :require => false
  gem 'simplecov-console', :require => false
end

gem 'rdoc' if RUBY_VERSION >= '3.1'
