[ 'host', 'command_factory', 'command', 'options', 'dsl/wrappers' ].each do |lib|
  require "beaker/#{lib}"
end

module PSWindows
  class Host < Beaker::Host
    [ 'user', 'group', 'exec', 'pkg', 'file' ].each do |lib|
      require "beaker/host/pswindows/#{lib}"
    end

    include PSWindows::User
    include PSWindows::Group
    include PSWindows::File
    include PSWindows::Exec
    include PSWindows::Pkg

    def self.pe_defaults
      h = Beaker::Options::OptionsHash.new
      h.merge({
        'user'          => 'Administrator',
        'group'         => 'Administrators',
        'distmoduledir' => 'C:\\ProgramData\\PuppetLabs\\puppet\\etc\\modules',
        'sitemoduledir' => 'C:\\usr\\share\\puppet\\modules',
        'puppetservice' => 'pe-httpd',
        'pathseparator' => ';',
        'puppetpath'    => 'C:\\ProgramData\\PuppetLabs\\puppet\\etc',
        'puppetconfdir' => 'C:\\ProgramData\\PuppetLabs\\puppet\\etc',
        'puppetcodedir' => 'C:\\ProgramData\\PuppetLabs\\puppet\\etc',
        'hieraconf'     => 'C:\\ProgramData\\PuppetLabs\\puppet\\etc\\hiera.yaml',
        'puppetvardir'  => 'C:\\ProgramData\\PuppetLabs\\puppet\\var',
        'puppetbindir'  => '"C:\\Program Files (x86)\\PuppetLabs\\Puppet Enterprise\\bin";"C:\\Program Files\\PuppetLabs\\Puppet Enterprise\\bin"'
      })
    end

    def self.foss_defaults
      h = Beaker::Options::OptionsHash.new
      h.merge({
        'user'              => 'Administrator',
        'group'             => 'Administrators',
        'distmoduledir'     => 'C:\\ProgramData\\PuppetLabs\\puppet\\etc\\modules',
        'sitemoduledir'     => 'C:\\usr\\share\\puppet\\modules',
        'hieralibdir'       => 'C:\\opt\\puppet-git-repos\\hiera\\lib',
        'hierapuppetlibdir' => 'C:\\opt\\puppet-git-repos\\hiera-puppet\\lib',
        'hierabindir'       => 'C:\\opt\\puppet-git-repos\\hiera\\bin',
        'pathseparator'     => ';',
        'puppetpath'        => '"C:\\Program Files (x86)\\Puppet Labs\\Puppet\\etc";"C:\\Program Files\\Puppet Labs\\Puppet\\etc"',
        'hieraconf'         => '"C:\\Program Files (x86)\\Puppet Labs\\Puppet\\etc\\hiera.yaml";"C:\\Program Files\\Puppet Labs\\Puppet\\etc\\hiera.yaml"',
        'puppetvardir'      => '"C:\\Program Files (x86)\\Puppet Labs\\Puppet\\var";"C:\\Program Files\\Puppet Labs\\Puppet\\var"',
        'puppetbindir'      => '"C:\\Program Files (x86)\\Puppet Labs\\Puppet\\bin";"C:\\Program Files\\Puppet Labs\\Puppet\\bin"',
      })
    end
  end
end
