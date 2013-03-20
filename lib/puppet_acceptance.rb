require 'rubygems' unless defined?(Gem)
module PuppetAcceptance

  %w( test_suite test_config result command options_parsing cli ).each do |lib|
    begin
      require "puppet_acceptance/#{lib}"
    rescue LoadError
      require File.expand_path(File.join(File.dirname(__FILE__), 'puppet_acceptance', lib))
    end
  end
  # These really are our sub-systems that live within the harness today
  # Ideally I would like to see them split out into modules that can be
  # included as such here
  #
  # The Testing DSL
  require 'puppet_acceptance/dsl'
  #
  # Our Host Abstraction Layer
  require 'puppet_acceptance/host'
  #
  # How we manage connecting to hosts and hypervisors
  #require 'puppet_acceptance/connectivity'
  #
  # Our test runner, suite, test cases and steps
  #require 'puppet_acceptance/runner'
  #
  # Common setup and testing steps
  #require 'puppet_acceptance/steps'
  #
  # Common Utils
  #require 'puppet_acceptance/utils'

end
