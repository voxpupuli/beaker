[ 'install_utils', 'roles', 'outcomes', 'assertions',
  'structure', 'helpers', 'ezbake_utils', 'wrappers' ].each do |lib|
  require "beaker/dsl/#{lib}"
end

module Beaker
  # This is a catch all module for including Puppetlabs home grown testing
  # DSL. This module is mixed into {Beaker::TestCase} and can be
  # mixed into any test runner by defining the methods that it requires to
  # interact with. If not all of the functionality is required sub modules of
  # the DSL may be mixed into a test runner of your choice.
  #
  # Currently most DSL modules require #logger and #hosts defined. #logger
  # should provided the methods #debug, #warn and #notify and may be a
  # wrapper to any logger you wish (or {Beaker::Logger}). #hosts
  # should return an array of objects which conform to the interface defined
  # in {Beaker::Host} (primarily it should provide Hash like access
  # and interfaces like {Beaker::Host#exec},
  # {Beaker::Host#do_scp_to}, and
  # {Beaker::Host#do_scp_from}.
  #
  #
  # @example Writing a complete testcase to be ran by the builtin test runner.
  #     test_name 'Ensure My App Starts Correctly' do
  #       confine :except, :platform => ['windows', 'solaris']
  #
  #       teardown do
  #         on master, puppet('resource mything ensure=absent')
  #         on agents, 'kill -9 allTheThings'
  #       end
  #
  #       step 'Ensure Pre-Requisites are Installed' do
  #       end
  #
  #       with_puppet_running_on master, :master, :logdest => '/tmp/blah' do
  #
  #         step 'Run Startup Script' do
  #         end
  #
  #         step 'And... Did it work?' do
  #         end
  #       end
  #     end
  #
  # @example Writing an Example to be ran within RSpec
  #     #=> spec_helper.rb
  #       RSpec.configure do |c|
  #         c.include 'beaker/dsl/helpers'
  #         c.include 'beaker/dsl/rspec/matchers'
  #         c.include 'beaker/dsl/rspec/expectations'
  #         c.include 'beaker/host'
  #       end
  #
  #     #=> my_acceptance_spec.rb
  #     require 'spec_helper'
  #
  #     describe 'A Test With RSpec' do
  #       let(:hosts)  { Host.new('blah', 'blah', 'not helpful' }
  #       let(:logger) { Where.is('the', 'rspec', 'logger')     }
  #
  #       after do
  #         on master, puppet('resource mything ensure=absent')
  #         on agents, 'kill -9 allTheThings'
  #       end
  #
  #       it 'tests stuff?' do
  #         result = on( hosts.first, 'ls ~' )
  #         expect( result.stdout ).to match /my_file/
  #       end
  #     end
  #
  module DSL
    include Beaker::DSL::Roles
    include Beaker::DSL::Outcomes
    include Beaker::DSL::Structure
    include Beaker::DSL::Assertions
    include Beaker::DSL::Wrappers
    include Beaker::DSL::Helpers
    include Beaker::DSL::EZBakeUtils
    include Beaker::DSL::InstallUtils
  end
end
