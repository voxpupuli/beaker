# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require 'rbconfig'
ruby_conf = defined?(RbConfig) ? RbConfig::CONFIG : Config::CONFIG
less_than_one_nine = ruby_conf['MAJOR'].to_i == 1 && ruby_conf['MINOR'].to_i < 9

Gem::Specification.new do |s|
  s.name        = "beaker"
  s.version     = '1.0.0'
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

  # Testing dependencies
  s.add_development_dependency 'rspec', '~> 2.14.0'
  s.add_development_dependency 'fakefs', '0.4'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'simplecov' unless less_than_one_nine

  # Documentation dependencies
  s.add_development_dependency 'yard'
  s.add_development_dependency 'markdown' unless less_than_one_nine
  s.add_development_dependency 'thin'

  # Run time dependencies
  s.add_runtime_dependency 'json'
  s.add_runtime_dependency 'net-ssh'
  s.add_runtime_dependency 'net-scp'
  s.add_runtime_dependency 'rbvmomi'
  s.add_runtime_dependency 'blimpy'
  s.add_runtime_dependency 'nokogiri', '1.5.10'
  s.add_runtime_dependency 'mime-types', '1.25' if RUBY_VERSION < "1.9"
  s.add_runtime_dependency 'fission' if RUBY_PLATFORM =~ /darwin/i
  s.add_runtime_dependency 'inifile'
  #unf is an 'optional' fog dependency, but it warns when it is missing
  #  see https://github.com/fog/fog/pull/2320/commits
  #  uncomment to remove unf warning
  #s.add_runtime_dependency 'unf'
end
