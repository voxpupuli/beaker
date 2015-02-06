[ 'host', 'command_factory', 'command', 'options' ].each do |lib|
  require "beaker/#{lib}"
end

module Mac
  class Host < Beaker::Host

    [ 'exec', 'file' ].each do |lib|
      require "beaker/host/unix/#{lib}"
    end
    [ 'user', 'group' ].each do |lib|
      require "beaker/host/mac/#{lib}"
    end

    include Mac::User
    include Mac::Group
    include Unix::File
    include Unix::Exec

    def self.pe_defaults
      h = Beaker::Options::OptionsHash.new
      h.merge({
        'user'          => 'root',
        'group'         => 'pe-puppet',
        'puppetserver-confdir' => '/etc/puppetlabs/puppetserver/conf.d',
        'puppetservice'    => 'pe-httpd',
        'puppetpath'       => '/etc/puppetlabs/puppet',
        'puppetconfdir'    => '/etc/puppetlabs/puppet',
        'puppetcodedir'    => '/etc/puppetlabs/puppet',
        'puppetbin'        => '/opt/puppet/bin/puppet',
        'puppetbindir'     => '/opt/puppet/bin',
        'puppetsbindir'    => '/opt/puppet/sbin',
        'puppetvardir'     => '/var/opt/lib/pe-puppet',
        'hieradatadir'     => '/var/lib/hiera',
        'hieraconf'        => '/etc/puppetlabs/puppet/hiera.yaml',
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
        'puppetcodedir'     => '/etc/puppet',
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
      })
    end
  end
end
