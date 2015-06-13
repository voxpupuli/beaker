[ 'foss', 'pe', 'puppet', 'ezbake', 'module' ].each do |lib|
    require "beaker/dsl/install_utils/#{lib}_utils"
end

module Beaker
  module DSL
    # Collection of installation methods and support
    module InstallUtils
      include DSL::InstallUtils::PuppetUtils
      include DSL::InstallUtils::PEUtils
      include DSL::InstallUtils::FOSSUtils
      include DSL::InstallUtils::ModuleUtils
      include DSL::InstallUtils::EZBakeUtils
    end
  end
end
