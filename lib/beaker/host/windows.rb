[ 'host', 'command_factory', 'command', 'options' ].each do |lib|
      require "beaker/#{lib}"
end

module Windows
  class Host < Beaker::Host
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
        'hieraconf'     => '`cygpath -smF 35`/Puppetlabs/puppet/etc/hiera.yaml',
        'puppetvardir'  => '`cygpath -smF 35`/PuppetLabs/puppet/var',
        'distmoduledir' => '`cygpath -smF 35`/PuppetLabs/puppet/etc/modules',
        'sitemoduledir' => 'C:/usr/share/puppet/modules',
        #if an x86 Puppet Labs dir exists then use it, default to non-x86 Program Files directory
        'puppetbindir'  => '$( [ -d "/cygdrive/c/Program Files (x86)/Puppet Labs/Puppet Enterprise/bin" ] && echo "/cygdrive/c/Program Files (x86)" || echo "/cygdrive/c/Program Files" )/Puppet Labs/Puppet Enterprise/bin',
        'pathseparator' => ';',
      })
    end

    def self.foss_defaults
      h = Beaker::Options::OptionsHash.new
      h.merge({
        'user'              => 'Administrator',
        'group'             => 'Administrators',
        'puppetpath'        => '`cygpath -smF 35`/PuppetLabs/puppet/etc',
        'hieraconf'         => '`cygpath -smF 35`/Puppetlabs/puppet/etc/hiera.yaml',
        'puppetvardir'      => '`cygpath -smF 35`/PuppetLabs/puppet/var',
        'distmoduledir'     => '`cygpath -smF 35`/PuppetLabs/puppet/etc/modules',
        'sitemoduledir'     => 'C:/usr/share/puppet/modules',
        'hieralibdir'       => '`cygpath -w /opt/puppet-git-repos/hiera/lib`',
        'hierapuppetlibdir' => '`cygpath -w /opt/puppet-git-repos/hiera-puppet/lib`',
        # PATH related variables need to be Unix, which cygwin converts
        'puppetbindir'  => '$( [ -d "/cygdrive/c/Program Files (x86)/Puppet Labs/Puppet/bin" ] && echo "/cygdrive/c/Program Files (x86)" || echo "/cygdrive/c/Program Files" )/Puppet Labs/Puppet/bin',
        'hierabindir'       => '/opt/puppet-git-repos/hiera/bin',
        'pathseparator'     => ';',
      })
    end
  end
end
