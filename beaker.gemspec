# -*- encoding: utf-8 -*-
lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'beaker/version'

Gem::Specification.new do |s|
  s.name        = "beaker"
  s.version     = Beaker::Version::STRING
  s.authors     = ["Puppet"]
  s.email       = ["voxpupuli@groups.io"]
  s.homepage    = "https://github.com/voxpupuli/beaker"
  s.summary     = %q{Let's test Puppet!}
  s.description = %q{Puppet's accceptance testing harness}
  s.license     = 'Apache-2.0'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.required_ruby_version = Gem::Requirement.new('>= 2.4')

  # Testing dependencies
  s.add_development_dependency 'fakefs', '~> 1.0'
  s.add_development_dependency 'rake', '~> 13.0'
  s.add_development_dependency 'rspec', '~> 3.0'
  s.add_development_dependency 'rspec-its'

  # Documentation dependencies
  s.add_development_dependency 'yard', '~> 0.9.11'

  # Run time dependencies
  s.add_runtime_dependency 'minitar', '~> 0.6'
  s.add_runtime_dependency 'minitest', '~> 5.4'
  s.add_runtime_dependency 'rexml'

  s.add_runtime_dependency 'ed25519', '~> 1.0' # net-ssh compatibility with ed25519 keys
  s.add_runtime_dependency 'hocon', '~> 1.0'
  s.add_runtime_dependency 'inifile', '~> 3.0'
  s.add_runtime_dependency 'net-scp', '>= 1.2', '< 5.0'
  s.add_runtime_dependency 'net-ssh', '>= 5.0'

  s.add_runtime_dependency 'in-parallel', '~> 0.1'
  s.add_runtime_dependency 'open_uri_redirections', '~> 0.2.1'
  s.add_runtime_dependency 'rsync', '~> 1.0.9'
  s.add_runtime_dependency 'thor', ['>= 1.0.1', '< 2.0']

  # Run time dependencies that are Beaker libraries
  s.add_runtime_dependency 'beaker-hostgenerator'
  s.add_runtime_dependency 'stringify-hash', '~> 0.0'
end
