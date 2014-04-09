require File.expand_path(File.join(File.dirname(__FILE__), '..', 'host'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'command_factory'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'command'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'options'))

module Windows
  class Host < Beaker::Host
    require File.expand_path(File.join(File.dirname(__FILE__), 'windows', 'user'))
    require File.expand_path(File.join(File.dirname(__FILE__), 'windows', 'group'))
    require File.expand_path(File.join(File.dirname(__FILE__), 'windows', 'exec'))
    require File.expand_path(File.join(File.dirname(__FILE__), 'windows', 'pkg'))
    require File.expand_path(File.join(File.dirname(__FILE__), 'windows', 'file'))

    include Windows::User
    include Windows::Group
    include Windows::File
    include Windows::Exec
    include Windows::Pkg

    def self.pe_defaults
      h = Beaker::Options::OptionsHash.new
      h.merge({
        'user'          => 'Administrator',
        'group'         => 'Administrators',
        'service-wait'  => false,
        'puppetservice' => 'pe-httpd',
        'puppetpath'    => '`cygpath -smF 35`/PuppetLabs/puppet/etc',
        'puppetvardir'  => '`cygpath -smF 35`/PuppetLabs/puppet/var',
        #if an x86 Program Files dir exists then use it, default to just Program Files
        'puppetbindir'  => '$( [ -d "/cygdrive/c/Program Files (x86)" ] && echo "/cygdrive/c/Program Files (x86)" || echo "/cygdrive/c/Program Files" )/Puppet Labs/Puppet Enterprise/bin',
        'pathseparator' => ';',
      })
    end

    def self.foss_defaults
      h = Beaker::Options::OptionsHash.new
      h.merge({
        'user'              => 'Administrator',
        'group'             => 'Administrators',
        'puppetpath'        => '`cygpath -smF 35`/PuppetLabs/puppet/etc',
        'puppetvardir'      => '`cygpath -smF 35`/PuppetLabs/puppet/var',
        'hieralibdir'       => '`cygpath -w /opt/puppet-git-repos/hiera/lib`',
        'hierapuppetlibdir' => '`cygpath -w /opt/puppet-git-repos/hiera-puppet/lib`',
        # PATH related variables need to be Unix, which cygwin converts
        'hierabindir'       => '/opt/puppet-git-repos/hiera/bin',
        'pathseparator'     => ';',
      })
    end
  end
end
