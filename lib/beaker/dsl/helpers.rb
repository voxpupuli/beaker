# -*- coding: utf-8 -*-
[ 'host', 'test', 'web', 'hocon' ].each do |lib|
      require "beaker/dsl/helpers/#{lib}_helpers"
end

require "beaker-hiera"
require 'beaker-puppet'
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
    # * a method *metadata* that yields a hash
    #
    #
    module Helpers
      include Beaker::DSL::Helpers::HostHelpers
      include Beaker::DSL::Helpers::TestHelpers
      include Beaker::DSL::Helpers::WebHelpers
      include Beaker::DSL::Helpers::HoconHelpers
      include Beaker::DSL::Helpers::Hiera
      include BeakerPuppet::Helpers
    end
  end
end
