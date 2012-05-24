require File.expand_path(File.join(File.dirname(__FILE__), '..', 'host'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'command_factory'))

module Unix
  class Host < PuppetAcceptance::Host
    require File.expand_path(File.join(File.dirname(__FILE__), 'unix', 'user'))
    require File.expand_path(File.join(File.dirname(__FILE__), 'unix', 'group'))
    require File.expand_path(File.join(File.dirname(__FILE__), 'unix', 'exec'))
    require File.expand_path(File.join(File.dirname(__FILE__), 'unix', 'file'))

    include Unix::User
    include Unix::Group
    include Unix::File
    include Unix::Exec

    PE_DEFAULTS = {
      'user'          => 'root',
      'puppetpath'    => '/etc/puppetlabs/puppet',
      'puppetbin'     => '/opt/puppet/bin/puppet',
      'puppetbindir'  => '/opt/puppet/bin',
      'pathseparator' => ':',
    }

    DEFAULTS = {
      'user'          => 'root',
      'puppetpath'    => '/etc/puppet',
      'puppetvardir'  => '/var/lib/puppet',
      'puppetbin'     => '/usr/bin/puppet',
      'puppetbindir'  => '/usr/bin',
      'hieralibdir'   => '/opt/puppet-git-repos/hiera/lib',
      'hierabindir'   => '/opt/puppet-git-repos/hiera/bin',
      'pathseparator' => ':',
    }

    def initialize(name, overrides, defaults)
      super(name, overrides, defaults)

      @defaults = defaults.merge(PuppetAcceptance::TestConfig.is_pe? ? PE_DEFAULTS : DEFAULTS)
    end
  end
end
