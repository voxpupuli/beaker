[ 'host', 'command_factory' ].each do |lib|
  require "beaker/#{lib}"
end

module FreeBSD
  class Host < Unix::Host

    [
      'exec',
    ].each do |lib|
        require "beaker/host/freebsd/#{lib}"
    end

    include FreeBSD::Exec

    def self.foss_defaults
      h = Beaker::Options::OptionsHash.new
      h.merge({
        'user'              => 'root',
        'group'             => 'puppet',
        'puppetserver-confdir' => '/etc/puppetserver/conf.d',
        'puppetservice'     => 'puppetmaster',
        'puppetpath'        => '/usr/local/etc/puppet/modules',
        'puppetvardir'      => '/var/lib/puppet',
        'puppetbin'         => '/usr/bin/puppet',
        'puppetbindir'      => '/usr/bin',
        'hieralibdir'       => '/opt/puppet-git-repos/hiera/lib',
        'hierapuppetlibdir' => '/opt/puppet-git-repos/hiera-puppet/lib',
        'hierabindir'       => '/opt/puppet-git-repos/hiera/bin',
        'hieradatadir'      => '/usr/local/etc/puppet/modules/hieradata',
        'hieraconf'         => '/usr/local/etc/puppet/modules/hiera.yaml',
        'distmoduledir'     => '/usr/local/etc/puppet/modules',
        'sitemoduledir'     => '/usr/share/puppet/modules',
        'pathseparator'     => ':',
        })
    end
  end

end
