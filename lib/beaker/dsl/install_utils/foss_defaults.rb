module Beaker
  module DSL
    module InstallUtils
      #
      # This module contains default values for FOSS puppet paths and directorys per-platform
      #
      module FOSSDefaults

        #Here be the default download URLs
        FOSS_DEFAULT_DOWNLOAD_URLS = {
          :win_download_url       => "http://downloads.puppetlabs.com/windows",
          :mac_download_url       => "http://downloads.puppetlabs.com/mac",
          :pe_promoted_builds_url => "http://pm.puppetlabs.com",
          :release_apt_repo_url   => "http://apt.puppetlabs.com",
          :release_yum_repo_url   => "http://yum.puppetlabs.com",
          :dev_builds_url         => "http://builds.delivery.puppetlabs.net",
        }

        #Here be the pathing and default values for FOSS installs
        #
        FOSS_DEFAULTS = {
          'freebsd' => {
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
          },
          'openbsd' => {
            'puppetserver-confdir' => '/etc/puppetserver/conf.d',
            'puppetservice'     => 'puppetmaster',
            'puppetpath'        => '/etc/puppet/modules',
            'puppetvardir'      => '/var/puppet',
            'puppetbin'         => '/usr/local/bin/puppet',
            'puppetbindir'      => '/usr/local/bin',
            'hieralibdir'       => '/opt/puppet-git-repos/hiera/lib',
            'hierapuppetlibdir' => '/opt/puppet-git-repos/hiera-puppet/lib',
            'hierabindir'       => '/opt/puppet-git-repos/hiera/bin',
            'hieradatadir'      => '/etc/puppet/hieradata',
            'hieraconf'         => '/etc/puppet/hiera.yaml',
            'distmoduledir'     => '/etc/puppet/modules',
            'sitemoduledir'     => '/usr/local/share/puppet/modules',
          },
          'mac' => {
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
          },
          'unix' => {
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
            'distmoduledir'     => '/etc/puppet/modules',
            'sitemoduledir'     => '/usr/share/puppet/modules',
          },
          'archlinux' => {
            'puppetserver-confdir' => '/etc/puppetserver/conf.d',
            'puppetservice'     => 'puppetmaster',
            'puppetpath'        => '/etc/puppetlabs/puppet',
            'puppetconfdir'     => '/etc/puppetlabs/puppet',
            'puppetvardir'      => '/opt/puppetlabs/puppet/cache',
            'puppetbin'         => '/usr/bin/puppet',
            'puppetbindir'      => '/usr/bin',
            'privatebindir'     => '/usr/bin',
            'hieralibdir'       => '/var/lib/hiera',
            'hierapuppetlibdir' => '/opt/puppet-git-repos/hiera-puppet/lib',
            'hierabindir'       => '/usr/bin',
            'hieradatadir'      => '/etc/puppetlabs/code/hiera',
            'hieraconf'         => '/etc/hiera.yaml',
            'distmoduledir'     => '/etc/puppetlabs/code/modules',
            'sitemoduledir'     => '/usr/share/puppet/modules',
          },
          'windows' => { #cygwin windows
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
          },
          'pswindows' => { #windows windows
            'distmoduledir'     => 'C:\\ProgramData\\PuppetLabs\\puppet\\etc\\modules',
            'sitemoduledir'     => 'C:\\usr\\share\\puppet\\modules',
            'hieralibdir'       => 'C:\\opt\\puppet-git-repos\\hiera\\lib',
            'hierapuppetlibdir' => 'C:\\opt\\puppet-git-repos\\hiera-puppet\\lib',
            'hierabindir'       => 'C:\\opt\\puppet-git-repos\\hiera\\bin',
            'puppetpath'        => '"C:\\Program Files (x86)\\Puppet Labs\\Puppet\\etc";"C:\\Program Files\\Puppet Labs\\Puppet\\etc"',
            'hieraconf'         => '"C:\\Program Files (x86)\\Puppet Labs\\Puppet\\etc\\hiera.yaml";"C:\\Program Files\\Puppet Labs\\Puppet\\etc\\hiera.yaml"',
            'puppetvardir'      => '"C:\\Program Files (x86)\\Puppet Labs\\Puppet\\var";"C:\\Program Files\\Puppet Labs\\Puppet\\var"',
            'puppetbindir'      => '"C:\\Program Files (x86)\\Puppet Labs\\Puppet\\bin";"C:\\Program Files\\Puppet Labs\\Puppet\\bin"',
          },
        }


        # Add the appropriate foss defaults to the host object so that they can be accessed using host[option], set host[:type] = foss
        # @param [Host] host    A single host to act upon
        # @param [String] platform The platform type of this host, one of windows, pswindows, freebsd, mac & unix
        def add_platform_foss_defaults(host, platform)
          FOSS_DEFAULTS[platform].each_pair do |key, val|
            host[key] = val
          end
          # add the group and type for backwards compatability 
          if host['platform'] =~ /windows/
            host['group'] = 'Administrators'
          else
            host['group'] = 'puppet'
          end
          host['type'] = 'foss'
        end

        # Add the appropriate foss defaults to an array of hosts
        # @param [Host, Array<Host>, String, Symbol] hosts    One or more hosts to act upon,
        #                            or a role (String or Symbol) that identifies one or more hosts.
        def add_foss_defaults_on(hosts)
          block_on hosts do | host |
            case host.class.to_s.downcase
            when /aix|unix/
              platform = 'unix'
            when /freebsd/
              platform = 'freebsd'
            when /openbsd/
              platform = 'openbsd'
            when /mac/
              platform = 'mac'
            when /pswindows/
              platform = 'pswindows'
            when /archlinux/
              platform = 'archlinux'
            else
              platform = 'windows'
            end
            add_platform_foss_defaults(host, platform)
          end
        end

        # Remove the appropriate foss defaults from the host object so that they can no longer be accessed using host[option], set host[:type] = nil
        # @param [Host] host    A single host to act upon
        # @param [String] platform The platform type of this host, one of windows, pswindows, freebsd, mac & unix
        def remove_platform_foss_defaults(host, platform)
          FOSS_DEFAULTS[platform].each_pair do |key, val|
            host.delete(key)
          end
          host['group'] = nil
          host['type'] = nil
        end

        # Remove the appropriate foss defaults from an array of hosts
        # @param [Host, Array<Host>, String, Symbol] hosts    One or more hosts to act upon,
        #                            or a role (String or Symbol) that identifies one or more hosts.
        def remove_foss_defaults_on(hosts)
          block_on hosts do | host |
            case host.class.to_s.downcase
            when /aix|unix/
              platform = 'unix'
            when /freebsd/
              platform = 'freebsd'
            when /openbsd/
              platform = 'openbsd'
            when /mac/
              platform = 'mac'
            when /pswindows/
              platform = 'pswindows'
            else
              platform = 'windows'
            end
            remove_platform_foss_defaults(host, platform)
          end
        end

      end
    end
  end
end

