# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require 'rbconfig'
ruby_conf = defined?(RbConfig) ? RbConfig::CONFIG : Config::CONFIG
less_than_one_nine = ruby_conf['MAJOR'].to_i == 1 && ruby_conf['MINOR'].to_i < 9

Gem::Specification.new do |s|
  s.name        = "puppet_acceptance"
  s.version     = '0.0.1'
  s.authors     = ["Puppetlabs"]
  s.email       = ["sqa@puppetlabs.com"]
  s.homepage    = "https://github.com/puppetlabs/puppet-acceptance"
  s.summary     = %q{Write a gem summary}
  s.description = %q{Write a gem description}

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # Testing dependencies
  s.add_development_dependency 'rspec', '2.11.0'
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
  s.add_runtime_dependency 'fission' if RUBY_PLATFORM =~ /darwin/i
  s.add_runtime_dependency 'inifile'
end
