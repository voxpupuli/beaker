[ 'host', 'command_factory', 'command', 'options' ].each do |lib|
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
        'sitemoduledir'     => 'C:\\usr\\share\\puppet\\modules',
        'puppetservice' => 'pe-httpd',
        'pathseparator' => ';',
        'puppetpath'    => 'C:\\ProgramData\\PuppetLabs\\puppet\\etc',
        'puppetconfdir' => 'C:\\ProgramData\\PuppetLabs\\puppet\\etc',
        'puppetcodedir' => 'C:\\ProgramData\\PuppetLabs\\puppet\\etc',
        'hieraconf'     => 'C:\\ProgramData\\PuppetLabs\\puppet\\etc\\hiera.yaml',
        'puppetvardir'  => 'C:\\ProgramData\\PuppetLabs\\puppet\\var',
        })

        if platform.include?('amd64')
          h.merge({
            'puppetbindir'  => 'C:\\Program Files (x86)\\PuppetLabs\\Puppet Enterprise\\bin'
            })
          else
            h.merge({
              'puppetbindir'  => 'C:\\Program Files\\PuppetLabs\\Puppet Enterprise\\bin'
              })
            end
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
              'pathseparator'     => ';'
              })

              if h['platform'] && h['platform'].include?('amd64')
                h.merge({
                  'puppetpath'    => "C:\\Program Files (x86)\\Puppet Labs\\Puppet\\etc",
                  'puppetconfdir' => "C:\\Program Files (x86)\\Puppet Labs\\Puppet\\etc",
                  'puppetcodedir' => "C:\\Program Files (x86)\\Puppet Labs\\Puppet\\etc",
                  'hieraconf'     => "C:\\Program Files (x86)\\Puppet Labs\\Puppet\\etc\\hiera.yaml",
                  'puppetvardir'  => 'C:\\Program Files (x86)\\Puppet Labs\\Puppet\\var',
                  'puppetbindir'  => "C:\\Program Files (x86)\\Puppet Labs\\Puppet\\bin"
                  })
                else
                  h.merge({
                    'puppetpath'    => "C:\\Program Files\\Puppet Labs\\Puppet\\etc",
                    'puppetconfdir' => "C:\\Program Files\\Puppet Labs\\Puppet\\etc",
                    'puppetcodedir' => "C:\\Program Files\\Puppet Labs\\Puppet\\etc",
                    'hieraconf'     => "C:\\Program Files\\Puppet Labs\\Puppet\\etc\\hiera.yaml",
                    'puppetvardir'  => 'C:\\Program Files\\Puppet Labs\\Puppet\\var',
                    'puppetbindir'  => "C:\\Program Files\\Puppet Labs\\Puppet\\bin"
                    })
                  end

                end
              end
            end
