source ENV['GEM_SOURCE'] || "https://rubygems.org"

def location_for(place, fake_version = nil)
  if place =~ /^(git:[^#]*)#(.*)/
    [fake_version, { :git => $1, :branch => $2, :require => false }].compact
  elsif place =~ /^file:\/\/(.*)/
    ['>= 0', { :path => File.expand_path($1), :require => false }]
  else
    [place, { :require => false }]
  end
end

scooter_version = ENV['SCOOTER_VERSION']
if ENV['GEM_SOURCE'] =~ /rubygems\.delivery\.puppetlabs\.net/
  if scooter_version
    gem 'scooter', *location_for(scooter_version)
  else
    gem 'scooter', '~> 2.0'
  end
end

gemspec
