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
  s.executables   = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.required_ruby_version = Gem::Requirement.new('>= 2.7')

  # Testing dependencies
  s.add_development_dependency 'fakefs', '~> 2.4'
  s.add_development_dependency 'rake', '~> 13.0'
  s.add_development_dependency 'rspec', '~> 3.0'
  s.add_development_dependency 'voxpupuli-rubocop', '~> 2.3.0'

  # Run time dependencies
  s.add_runtime_dependency 'minitar', '~> 0.6'
  s.add_runtime_dependency 'minitest', '~> 5.4'
  s.add_runtime_dependency 'rexml', '~> 3.2', '>= 3.2.5'

  # net-ssh compatibility with ed25519 keys
  s.add_runtime_dependency 'bcrypt_pbkdf', '>= 1.0', '< 2.0'
  s.add_runtime_dependency 'ed25519', '>= 1.2', '<2.0'

  s.add_runtime_dependency 'hocon', '~> 1.0'
  s.add_runtime_dependency 'inifile', '~> 3.0'
  s.add_runtime_dependency 'net-scp', '>= 1.2', '< 5.0'
  s.add_runtime_dependency 'net-ssh', '~> 7.1'

  s.add_runtime_dependency 'in-parallel', '>= 0.1', '< 2.0'
  s.add_runtime_dependency 'rsync', '~> 1.0.9'
  s.add_runtime_dependency 'thor', ['>= 1.0.1', '< 2.0']

  # Run time dependencies that are Beaker libraries
  s.add_runtime_dependency 'beaker-hostgenerator', '~> 2.0'
  s.add_runtime_dependency 'stringify-hash', '~> 0.0'
end
