%w(install_utils roles outcomes assertions structure helpers wrappers).each do |file|
  begin
    require "puppet_acceptance/dsl/#{file}"
  rescue LoadError
    require File.expand_path(File.join(File.dirname(__FILE__), 'dsl', file))
  end
end

module PuppetAcceptance
  module DSL
    include PuppetAcceptance::DSL::Roles
    include PuppetAcceptance::DSL::Outcomes
    include PuppetAcceptance::DSL::Structure
    include PuppetAcceptance::DSL::Assertions
    include PuppetAcceptance::DSL::Wrappers
    include PuppetAcceptance::DSL::Helpers
    include PuppetAcceptance::DSL::InstallUtils
  end
end
