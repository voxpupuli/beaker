module PuppetAcceptance

  # These really are our sub-systems that live within the harness today
  # Ideally I would like to see them split out into modules that can be
  # included as such here
  #
  # The Testing DSL
  #require 'puppet_acceptance/dsl'
  #
  # Our Host Abstraction Layer
  #require 'puppet_acceptance/hosts'
  #
  # How we manage connecting to hosts and hypervisors
  #require 'puppet_acceptance/connectivity'
  #
  # Our test runner, suite, test cases and steps
  #require 'puppet_acceptance/runner'
  #
  # Common setup and testing steps
  #require 'puppet_acceptance/steps'

  Dir[File.expand_path(File.join(File.dirname(__FILE__), 'puppet_acceptance', '*.rb'))].each do |file|
    require file
  end
  #include PuppetCommands
  #include CommandFactory

end
