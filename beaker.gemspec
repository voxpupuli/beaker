lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'beaker/version'

Gem::Specification.new do |s|
  s.name        = "beaker"
  s.version     = Beaker::Version::STRING
  s.authors     = ["Puppet", "Vox Pupuli"]
  s.email       = ["voxpupuli@groups.io"]
  s.homepage    = "https://github.com/voxpupuli/beaker"
  s.summary     = %q{Let's test Puppet!}
  s.description = %q{Puppet's accceptance testing harness}
  s.license     = 'Apache-2.0'

  s.files         = `git ls-files`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.required_ruby_version = Gem::Requirement.new('>= 3.2')

  # Testing dependencies
  s.add_development_dependency 'fakefs', '>= 2.4', '< 4'
  s.add_development_dependency 'rake', '~> 13.0'
  s.add_development_dependency 'rspec', '~> 3.0'
  s.add_development_dependency 'voxpupuli-rubocop', '~> 5.1.0'

  # Run time dependencies
  # Required for Ruby 3.3+ support
  s.add_dependency 'base64', '>= 0.2.0', '< 1'
  s.add_dependency 'benchmark', '>= 0.3', '< 0.6'
  # we cannot require 1.0.2 because that requires Ruby 3.1
  s.add_dependency 'minitar', '>= 0.12', '< 2'
  s.add_dependency 'minitest', '>= 5.4', '< 7'
  s.add_dependency 'rexml', '~> 3.2', '>= 3.2.5'

  # readline is a bundled gem since Ruby 4
  s.add_dependency 'readline', '~> 0.0.4'

  # YAML::PStore depends on pstore, which is a bundled gem since Ruby 4
  # https://github.com/ruby/yaml/issues/69
  s.add_dependency 'pstore', '< 1'

  # net-ssh needs logger
  # https://github.com/net-ssh/net-ssh/pull/984
  s.add_dependency 'logger', '< 2'

  # net-ssh compatibility with ed25519 keys
  s.add_dependency 'bcrypt_pbkdf', '>= 1.0', '< 2.0'
  s.add_dependency 'ed25519', '>= 1.2', '<2.0'

  s.add_dependency 'hocon', '~> 1.0'
  s.add_dependency 'inifile', '~> 3.0'
  s.add_dependency 'net-scp', '>= 1.2', '< 5.0'
  s.add_dependency 'net-ssh', '~> 7.1'

  s.add_dependency 'in-parallel', '>= 0.1', '< 2.0'
  s.add_dependency 'rsync', '~> 1.0.9'
  s.add_dependency 'thor', ['>= 1.0.1', '< 2.0']

  # Run time dependencies that are Beaker libraries
  s.add_dependency 'beaker-hostgenerator', '~> 3.0'
  s.add_dependency 'stringify-hash', '~> 0.0'
end
