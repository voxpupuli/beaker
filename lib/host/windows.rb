require 'host'

module Windows
  class Host < Host


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
