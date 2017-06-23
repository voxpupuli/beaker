require "beaker/dsl/install_utils/pe_defaults"
require 'beaker-puppet'

module Beaker
  module DSL
    # Collection of installation methods and support
    module InstallUtils
      include DSL::InstallUtils::PEDefaults
      include BeakerPuppet::InstallUtils
    end
  end
end
