require 'lib/host'
require 'lib/command_factory'

module Windows
  class Host < Host
    require 'lib/host/windows/user'
    require 'lib/host/windows/group'
    require 'lib/host/windows/file'
    require 'lib/host/windows/exec'

    include Windows::User
    include Windows::Group
    include Windows::File
    include Windows::Exec

    PE_DEFAULTS = {
      'user'         => 'Administrator',
      'group'        => 'Administrators',
      'puppetpath'   => '`cygpath -smF 35`/PuppetLabs/puppet/etc',
      'puppetvardir' => '`cygpath -smF 35`/PuppetLabs/puppet/var',
      'puppetbindir' => 'C:/PROGRA~1/PUPPET~1/PUPPET~1/bin',
      'puppetbin'    => 'C:/PROGRA~1/PUPPET~1/PUPPET~1/bin/puppet.bat',
      'facterbin'    => 'C:/PROGRA~1/PUPPET~1/PUPPET~1/bin/facter.bat'
    }

    DEFAULTS = {
      'user'         => 'Administrator',
      'group'        => 'Administrators',
      'puppetpath'   => '`cygpath -smF 35`/PuppetLabs/puppet/etc',
      'puppetvardir' => '`cygpath -smF 35`/PuppetLabs/puppet/var',
      'puppetbin'    => 'puppet',
      'facterbin'    => 'facter'
    }

    def initialize(name, overrides, defaults)
      super(name, overrides, defaults)

      @defaults = defaults.merge(TestConfig.is_pe? ? PE_DEFAULTS : DEFAULTS)
    end
  end
end
