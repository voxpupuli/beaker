[ 'foss', 'puppet', 'ezbake', 'module' ].each do |lib|
    require "beaker/dsl/install_utils/#{lib}_utils"
end
require "beaker/dsl/install_utils/pe_defaults"

module Beaker
  module DSL
    # Collection of installation methods and support
    module InstallUtils
      include DSL::InstallUtils::PuppetUtils
      include DSL::InstallUtils::PEDefaults
      include DSL::InstallUtils::FOSSUtils
      include DSL::InstallUtils::ModuleUtils
      include DSL::InstallUtils::EZBakeUtils
    end
  end
end
