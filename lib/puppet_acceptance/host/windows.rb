require File.expand_path(File.join(File.dirname(__FILE__), '..', 'host'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'command_factory'))

module Windows
  class Host < PuppetAcceptance::Host
    require File.expand_path(File.join(File.dirname(__FILE__), 'windows', 'user'))
    require File.expand_path(File.join(File.dirname(__FILE__), 'windows', 'group'))
    require File.expand_path(File.join(File.dirname(__FILE__), 'windows', 'exec'))
    require File.expand_path(File.join(File.dirname(__FILE__), 'windows', 'file'))

    include Windows::User
    include Windows::Group
    include Windows::File
    include Windows::Exec

    PE_DEFAULTS = {
      'user'          => 'Administrator',
      'group'         => 'Administrators',
      'puppetpath'    => '`cygpath -smF 35`/PuppetLabs/puppet/etc',
      'puppetvardir'  => '`cygpath -smF 35`/PuppetLabs/puppet/var',
      'puppetbindir'  => '`cygpath -F 38`/Puppet Labs/Puppet Enterprise/bin',
      'pathseparator' => ';',
    }

    DEFAULTS = {
      'user'          => 'Administrator',
      'group'         => 'Administrators',
      'puppetpath'    => '`cygpath -smF 35`/PuppetLabs/puppet/etc',
      'puppetvardir'  => '`cygpath -smF 35`/PuppetLabs/puppet/var',
      'hieralibdir'   => '`cygpath -w /opt/puppet-git-repos/hiera/lib`',
      # PATH related variables need to be Unix, which cygwin converts
      'hierabindir'   => '/opt/puppet-git-repos/hiera/bin',
      'pathseparator' => ';',
    }

    def initialize(name, overrides, defaults)
      super(name, overrides, defaults)

      @defaults = defaults.merge(PuppetAcceptance::TestConfig.is_pe? ? PE_DEFAULTS : DEFAULTS)
    end
  end
end
