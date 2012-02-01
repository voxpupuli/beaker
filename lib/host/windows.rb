require 'lib/host'
require 'lib/command_factory'

module Windows
  class Host < Host
    require 'lib/host/windows/user'
    require 'lib/host/windows/group'
    require 'lib/host/windows/file'

    include Windows::User
    include Windows::Group
    include Windows::File

    DEFAULTS = {
      'user'         => 'Administrator',
      'puppetpath'   => '"`cygpath -F 35`/PuppetLabs/puppet/etc"',
      'puppetvardir' => '"`cygpath -F 35`/PuppetLabs/puppet/var"'
    }

    def initialize(name, overrides, defaults)
      super(name, overrides, defaults)

      @defaults = defaults.merge(DEFAULTS)
    end
  end
end
