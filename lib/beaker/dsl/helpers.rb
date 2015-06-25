# -*- coding: utf-8 -*-
[ 'facter', 'hiera', 'host', 'puppet', 'test', 'tk', 'web' ].each do |lib|
      require "beaker/dsl/helpers/#{lib}_helpers"
end

module Beaker
  module DSL

    # Contains methods to help you manage and configure your SUTs and configure and interact with puppet, facter
    # and hiera.

    # To mix this is into a class you need the following:
    # * a method *hosts* that yields any hosts implementing
    #   {Beaker::Host}'s interface to act upon.
    # * a method *options* that provides an options hash, see {Beaker::Options::OptionsHash}
    # * a method *logger* that yields a logger implementing
    #   {Beaker::Logger}'s interface.
    # * the module {Beaker::DSL::Roles} that provides access to the various hosts implementing
    #   {Beaker::Host}'s interface to act upon
    # * the module {Beaker::DSL::Wrappers} the provides convenience methods for {Beaker::DSL::Command} creation
    #
    #
    module Helpers
      include Beaker::DSL::Helpers::FacterHelpers
      include Beaker::DSL::Helpers::HieraHelpers
      include Beaker::DSL::Helpers::HostHelpers
      include Beaker::DSL::Helpers::PuppetHelpers
      include Beaker::DSL::Helpers::TestHelpers
      include Beaker::DSL::Helpers::TKHelpers
      include Beaker::DSL::Helpers::WebHelpers
    end
  end
end
