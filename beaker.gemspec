# -*- encoding: utf-8 -*-
$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require 'beaker/version'

Gem::Specification.new do |s|
  s.name        = "beaker"
  s.version     = Beaker::Version::STRING
  s.authors     = ["Puppetlabs"]
  s.email       = ["delivery@puppetlabs.com"]
  s.homepage    = "https://github.com/puppetlabs/beaker"
  s.summary     = %q{Let's test Puppet!}
  s.description = %q{Puppetlabs accceptance testing harness}
  s.license     = 'Apache2'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.required_ruby_version = Gem::Requirement.new('>= 2.2.5')

  # Testing dependencies
  s.add_development_dependency 'rspec', '~> 3.0'
  s.add_development_dependency 'rspec-its'
  s.add_development_dependency 'fakefs', '~> 0.6'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'pry', '~> 0.10'

  # Documentation dependencies
  s.add_development_dependency 'yard', '< 0.9.6'

  # Run time dependencies
  s.add_runtime_dependency 'minitest', '~> 5.4'
  s.add_runtime_dependency 'minitar', '~> 0.5.4'

  s.add_runtime_dependency 'hocon', '~> 1.0'
  s.add_runtime_dependency 'net-ssh', '~> 4.0'
  s.add_runtime_dependency 'net-scp', '~> 1.2'
  s.add_runtime_dependency 'inifile', '~> 3.0'

  s.add_runtime_dependency 'rake', '~> 10.0'
  s.add_runtime_dependency 'rsync', '~> 1.0.9'
  s.add_runtime_dependency 'open_uri_redirections', '~> 0.2.1'
  s.add_runtime_dependency 'in-parallel', '~> 0.1'
  s.add_runtime_dependency 'thor', '0.19.1'

  # Run time dependencies that are Beaker libraries
  s.add_runtime_dependency 'stringify-hash', '~> 0.0'
  s.add_runtime_dependency 'beaker-hiera', '~> 0.0'
  s.add_runtime_dependency 'beaker-hostgenerator'

  # Optional provisioner specific support
  s.add_runtime_dependency 'rbvmomi', '~> 1.9'
  s.add_runtime_dependency 'fission', '~> 0.4'
  s.add_runtime_dependency 'google-api-client', '~> 0.9'
  s.add_runtime_dependency 'aws-sdk-v1', '~> 1.57'
  s.add_runtime_dependency 'docker-api'
  s.add_runtime_dependency 'fog', '~> 1.38'

  # So fog doesn't always complain of unmet AWS dependencies
  s.add_runtime_dependency 'unf', '~> 0.1'
end
