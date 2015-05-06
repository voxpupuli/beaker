[ 'host', 'command_factory', 'command', 'options' ].each do |lib|
      require "beaker/#{lib}"
end

module Windows
  # A windows host with cygwin tools installed
  class Host < Unix::Host
    [ 'user', 'group', 'exec', 'pkg', 'file' ].each do |lib|
          require "beaker/host/windows/#{lib}"
    end

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
        'puppetservice' => 'pe-httpd',
        'puppetpath'    => '`cygpath -smF 35`/PuppetLabs/puppet/etc',
        'puppetconfdir' => '`cygpath -smF 35`/PuppetLabs/puppet/etc',
        'puppetcodedir' => '`cygpath -smF 35`/PuppetLabs/puppet/etc',
        'hieraconf'     => '`cygpath -smF 35`/Puppetlabs/puppet/etc/hiera.yaml',
        'puppetvardir'  => '`cygpath -smF 35`/PuppetLabs/puppet/var',
        'distmoduledir' => '`cygpath -smF 35`/PuppetLabs/puppet/etc/modules',
        'sitemoduledir' => 'C:/usr/share/puppet/modules',
        #let's just add both potential bin dirs to the path
        'puppetbindir'  => '/cygdrive/c/Program Files (x86)/Puppet Labs/Puppet Enterprise/bin:/cygdrive/c/Program Files/Puppet Labs/Puppet Enterprise/bin',
        'privatebindir' => '/cygdrive/c/Program Files (x86)/Puppet Labs/Puppet Enterprise/sys/ruby/bin:/cygdrive/c/Program Files/Puppet Labs/Puppet Enterprise/sys/ruby/bin',
        'pathseparator' => ';',
      })
    end

    def self.foss_defaults
      h = Beaker::Options::OptionsHash.new
      h.merge({
        'user'              => 'Administrator',
        'group'             => 'Administrators',
        'puppetpath'        => '`cygpath -smF 35`/PuppetLabs/puppet/etc',
        'puppetconfdir'     => '`cygpath -smF 35`/PuppetLabs/puppet/etc',
        'puppetcodedir'     => '`cygpath -smF 35`/PuppetLabs/puppet/etc',
        'hieraconf'         => '`cygpath -smF 35`/Puppetlabs/puppet/etc/hiera.yaml',
        'puppetvardir'      => '`cygpath -smF 35`/PuppetLabs/puppet/var',
        'distmoduledir'     => '`cygpath -smF 35`/PuppetLabs/puppet/etc/modules',
        'sitemoduledir'     => 'C:/usr/share/puppet/modules',
        'hieralibdir'       => '`cygpath -w /opt/puppet-git-repos/hiera/lib`',
        'hierapuppetlibdir' => '`cygpath -w /opt/puppet-git-repos/hiera-puppet/lib`',
        #let's just add both potential bin dirs to the path
        'puppetbindir'      => '/cygdrive/c/Program Files (x86)/Puppet Labs/Puppet/bin:/cygdrive/c/Program Files/Puppet Labs/Puppet/bin',
        'privatebindir'     => '/usr/bin',
        'hierabindir'       => '/opt/puppet-git-repos/hiera/bin',
        'pathseparator'     => ';',
      })
    end

    def self.aio_defaults
      h = Beaker::Options::OptionsHash.new
      h.merge({
        'user'              => 'Administrator',
        'puppetbindir'      => '/cygdrive/c/Program Files (x86)/Puppet Labs/Puppet/bin:/cygdrive/c/Program Files/Puppet Labs/Puppet/bin',
        'privatebindir'     => '/cygdrive/c/Program Files (x86)/Puppet Labs/Puppet/sys/ruby/bin:/cygdrive/c/Program Files/Puppet Labs/Puppet/sys/ruby/bin',
        'distmoduledir'     => '`cygpath -smF 35`/PuppetLabs/code/modules',
        # sitemoduledir not included (check PUP-4049 for more info)
        'pathseparator'     => ';',
        })
    end
  end
end
