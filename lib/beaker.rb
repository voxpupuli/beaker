require 'rubygems' unless defined?(Gem)
module Beaker

  %w( utils test_suite result command options network_manager cli ).each do |lib|
    begin
      require "beaker/#{lib}"
    rescue LoadError
      require File.expand_path(File.join(File.dirname(__FILE__), 'beaker', lib))
    end
  end
  # These really are our sub-systems that live within the harness today
  # Ideally I would like to see them split out into modules that can be
  # included as such here
  #
  # The Testing DSL
  require 'beaker/dsl'
  #
  # Our Host Abstraction Layer
  require 'beaker/host'
  #
  # Our Hypervisor Abstraction Layer
  require 'beaker/hypervisor'
  #
  # How we manage connecting to hosts and hypervisors
  #require 'beaker/connectivity'
  #
  # Our test runner, suite, test cases and steps
  #require 'beaker/runner'
  #
  # Common setup and testing steps
  #require 'beaker/steps'
  #
  # Shared methods and helpers
  require 'beaker/shared'

end
