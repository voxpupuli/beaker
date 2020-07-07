# -*- encoding: utf-8 -*-
lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'beaker/version'

Gem::Specification.new do |s|
  s.name        = "beaker"
  s.version     = Beaker::Version::STRING
  s.authors     = ["Puppet"]
  s.email       = ["delivery@puppet.com"]
  s.homepage    = "https://github.com/puppetlabs/beaker"
  s.summary     = %q{Let's test Puppet!}
  s.description = %q{Puppet's accceptance testing harness}
  s.license     = 'Apache2'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.required_ruby_version = Gem::Requirement.new('>= 2.4')

  # Testing dependencies
  s.add_development_dependency 'rspec', '~> 3.0'
  s.add_development_dependency 'rspec-its'
  s.add_development_dependency 'fakefs', '~> 0.6', '< 0.14.0'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'rake', '~> 12.0'

  # Provisioner dependencies - needed for acceptance tests
  # TODO: figure out how to remove these
  s.add_development_dependency 'beaker-aws', '~> 0.1'
  s.add_development_dependency 'beaker-abs', '~> 0.4'
  s.add_development_dependency 'beaker-vmpooler', '~> 1.0'

  # Documentation dependencies
  s.add_development_dependency 'yard', '~> 0.9.11'

  # Run time dependencies
  s.add_runtime_dependency 'minitest', '~> 5.4'
  s.add_runtime_dependency 'minitar', '~> 0.6'
  s.add_runtime_dependency 'pry-byebug', '~> 3.9'
  # pry-byebug can have issues with native readline libs so add rb-readline
  s.add_runtime_dependency 'rb-readline', '~> 0.5.3'

  s.add_runtime_dependency 'hocon', '~> 1.0'
  s.add_runtime_dependency 'net-ssh', '>= 5.0'
  s.add_runtime_dependency 'net-scp', '~> 1.2'
  s.add_runtime_dependency 'inifile', '~> 3.0'

  s.add_runtime_dependency 'rsync', '~> 1.0.9'
  s.add_runtime_dependency 'open_uri_redirections', '~> 0.2.1'
  s.add_runtime_dependency 'in-parallel', '~> 0.1'
  s.add_runtime_dependency 'thor', ['>= 1.0.1', '< 2.0']

  # Run time dependencies that are Beaker libraries
  s.add_runtime_dependency 'stringify-hash', '~> 0.0'
  s.add_runtime_dependency 'beaker-hostgenerator'
end
