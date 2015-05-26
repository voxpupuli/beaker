[ 'host', 'command_factory', 'command', 'options' ].each do |lib|
      require "beaker/#{lib}"
end

module Unix
  class Host < Beaker::Host
    [ 'user', 'group', 'exec', 'pkg', 'file' ].each do |lib|
          require "beaker/host/unix/#{lib}"
    end

    include Unix::User
    include Unix::Group
    include Unix::File
    include Unix::Exec
    include Unix::Pkg

    def self.pe_defaults
      h = Beaker::Options::OptionsHash.new
      h.merge({
        'user'          => 'root',
        'group'         => 'pe-puppet',
        'puppetserver-confdir' => '/etc/puppetlabs/puppetserver/conf.d',
        'puppetservice'    => 'pe-httpd',
        'puppetpath'       => '/etc/puppetlabs/puppet',
        'puppetconfdir'    => '/etc/puppetlabs/puppet',
        'puppetbin'        => '/opt/puppet/bin/puppet',
        'puppetbindir'     => '/opt/puppet/bin',
        'puppetsbindir'    => '/opt/puppet/sbin',
        'privatebindir'    => '/opt/puppetlabs/puppet/bin',
        'puppetvardir'     => '/var/opt/lib/pe-puppet',
        'hieradatadir'     => '/var/lib/hiera',
        'hieraconf'        => '/etc/puppetlabs/puppet/hiera.yaml',
        'facter-factsd'    => '/etc/puppetlabs/facter/facts.d',
        'distmoduledir'    => '/etc/puppetlabs/puppet/modules',
        'sitemoduledir'    => '/opt/puppet/share/puppet/modules',
        'pathseparator'    => ':',
      })
    end

    def self.foss_defaults
      h = Beaker::Options::OptionsHash.new
      h.merge({
        'user'              => 'root',
        'group'             => 'puppet',
        'puppetserver-confdir' => '/etc/puppetserver/conf.d',
        'puppetservice'     => 'puppetmaster',
        'puppetpath'        => '/etc/puppet',
        'puppetconfdir'     => '/etc/puppet',
        'puppetvardir'      => '/var/lib/puppet',
        'puppetbin'         => '/usr/bin/puppet',
        'puppetbindir'      => '/usr/bin',
        'privatebindir'     => '/usr/bin',
        'hieralibdir'       => '/opt/puppet-git-repos/hiera/lib',
        'hierapuppetlibdir' => '/opt/puppet-git-repos/hiera-puppet/lib',
        'hierabindir'       => '/opt/puppet-git-repos/hiera/bin',
        'hieradatadir'      => '/etc/puppet/hieradata',
        'hieraconf'         => '/etc/puppet/hiera.yaml',
        'facter-factsd'     => '/etc/facter/facts.d',
        'distmoduledir'     => '/etc/puppet/modules',
        'sitemoduledir'     => '/usr/share/puppet/modules',
        'pathseparator'     => ':',
      })
    end

    def self.aio_defaults
      h = Beaker::Options::OptionsHash.new
      h.merge({
        'user'                  => 'root',
        'puppetbindir'          => '/opt/puppetlabs/bin',
        'privatebindir'         => '/opt/puppetlabs/puppet/bin',
        'distmoduledir'         => '/etc/puppetlabs/code/modules',
        'sitemoduledir'         => '/opt/puppetlabs/puppet/modules',
        'facter-factsd'         => '/opt/puppetlabs/facter/facts.d',
        'pathseparator'         => ':',
      })
    end
  end
end
