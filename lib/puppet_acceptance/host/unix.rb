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

    def self.pe_defaults
      {
        'user'          => 'root',
        'group'         => 'pe-puppet',
        'puppetpath'    => '/etc/puppetlabs/puppet',
        'puppetbin'     => '/opt/puppet/bin/puppet',
        'puppetbindir'  => '/opt/puppet/bin',
        'puppetvardir'  => '/var/opt/lib/pe-puppet',
        'hieradatadir'  => '/var/lib/hiera',
        'hieraconf'     => '/etc/puppetlabs/puppet/hiera.yaml',
        'distmoduledir' => '/etc/puppetlabs/puppet/modules',
        'sitemoduledir' => '/opt/puppet/share/puppet/modules',
        'pathseparator' => ':',
      }
    end

    def self.foss_defaults
      {
        'user'              => 'root',
        'group'             => 'puppet',
        'puppetpath'        => '/etc/puppet',
        'puppetvardir'      => '/var/lib/puppet',
        'puppetbin'         => '/usr/bin/puppet',
        'puppetbindir'      => '/usr/bin',
        'hieralibdir'       => '/opt/puppet-git-repos/hiera/lib',
        'hierapuppetlibdir' => '/opt/puppet-git-repos/hiera-puppet/lib',
        'hierabindir'       => '/opt/puppet-git-repos/hiera/bin',
        'hieradatadir'      => '/etc/puppet/hieradata',
        'hieraconf'         => '/etc/puppet/hiera.yaml',
        'distmoduledir'     => '/etc/puppet/modules',
        'sitemoduledir'     => '/usr/share/puppet/modules',
        'pathseparator'     => ':',
      }
    end
  end
end
