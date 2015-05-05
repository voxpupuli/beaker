module Beaker
  module DSL
    module InstallUtils
      #
      # This module contains default values for pe paths and directorys per-platform
      #
      module PEDefaults

        #Here be the pathing and default values for PE installs
        #
        PE_DEFAULTS = {
          'mac' => {
            'puppetserver-confdir' => '/etc/puppetlabs/puppetserver/conf.d',
            'puppetservice'    => 'pe-puppetserver',
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
          },
          'unix' => {
            'puppetserver-confdir' => '/etc/puppetlabs/puppetserver/conf.d',
            'puppetservice'    => 'pe-puppetserver',
            'puppetpath'       => '/etc/puppetlabs/puppet',
            'puppetconfdir'    => '/etc/puppetlabs/puppet',
            'puppetbin'        => '/opt/puppet/bin/puppet',
            'puppetbindir'     => '/opt/puppet/bin',
            'puppetsbindir'    => '/opt/puppet/sbin',
            'privatebindir'    => '/opt/puppet/bin',
            'puppetvardir'     => '/var/opt/lib/pe-puppet',
            'hieradatadir'     => '/var/lib/hiera',
            'hieraconf'        => '/etc/puppetlabs/puppet/hiera.yaml',
            'distmoduledir'    => '/etc/puppetlabs/puppet/modules',
            'sitemoduledir'    => '/opt/puppet/share/puppet/modules',
          },
          'windows' => { #cygwin windows
            'puppetservice' => 'pe-puppetserver',
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
          },
          'pswindows' => { #windows windows
            'puppetservice' => 'pe-puppetserver',
            'puppetpath'    => 'C:\\ProgramData\\PuppetLabs\\puppet\\etc',
            'puppetconfdir' => 'C:\\ProgramData\\PuppetLabs\\puppet\\etc',
            'puppetcodedir' => 'C:\\ProgramData\\PuppetLabs\\puppet\\etc',
            'hieraconf'     => 'C:\\ProgramData\\PuppetLabs\\puppet\\etc\\hiera.yaml',
            'distmoduledir' => 'C:\\ProgramData\\PuppetLabs\\puppet\\etc\\modules',
            'sitemoduledir' => 'C:\\usr\\share\\puppet\\modules',
            'puppetvardir'  => 'C:\\ProgramData\\PuppetLabs\\puppet\\var',
            'puppetbindir'  => '"C:\\Program Files (x86)\\PuppetLabs\\Puppet Enterprise\\bin";"C:\\Program Files\\PuppetLabs\\Puppet Enterprise\\bin"'
          },
        }

        # Add the appropriate pe defaults to the host object so that they can be accessed using host[option], set host[:type] = pe
        # @param [Host] host    A single host to act upon
        # @param [String] platform The platform type of this host, one of windows, pswindows, mac & unix
        def add_platform_pe_defaults(host, platform)
          PE_DEFAULTS[platform].each_pair do |key, val|
            host[key] = val
          end
          # add the type and group here for backwards compatability 
          if host['platform'] =~ /windows/
            host['group'] = 'Administrators'
          else
            host['group'] = 'pe-puppet'
          end
          host['type'] = 'pe'
          # older pe requires a different puppetservice name, set it here on the master
          if host['roles'].include?('master')
            if host['pe_ver'] and (version_is_less(host['pe_ver'], '3.4'))
              host['puppetservice'] = 'pe-httpd'
            end
          end
        end

        # Add the appropriate pe defaults to an array of hosts
        # @param [Host, Array<Host>, String, Symbol] hosts    One or more hosts to act upon,
        #                            or a role (String or Symbol) that identifies one or more hosts.
        def add_pe_defaults_on(hosts)
          block_on hosts do | host |
            case host.class.to_s.downcase
            when /aix|(free|open)bsd|unix/
              platform = 'unix'
            when /mac/
              platform = 'mac'
            when /pswindows/
              platform = 'pswindows'
            else
              platform = 'windows'
            end
            add_platform_pe_defaults(host, platform)
          end
        end

        # Remove the appropriate pe defaults from the host object so that they can no longer be accessed using host[option], set host[:type] = nil
        # @param [Host] host    A single host to act upon
        # @param [String] platform The platform type of this host, one of windows, freebsd, mac & unix
        def remove_platform_pe_defaults(host, platform)
          PE_DEFAULTS[platform].each_pair do |key, val|
            host.delete(key)
          end
          host['group'] = nil
          host['type'] = nil
        end

        # Remove the appropriate pe defaults from an array of hosts
        # @param [Host, Array<Host>, String, Symbol] hosts    One or more hosts to act upon,
        #                            or a role (String or Symbol) that identifies one or more hosts.
        def remove_pe_defaults_on(hosts)
          block_on hosts do | host |
            case host.class.to_s.downcase
            when /aix|(free|open)bsd|unix/
              platform = 'unix'
            when /mac/
              platform = 'mac'
            when /pswindows/
              platform = 'pswindows'
            else
              platform = 'windows'
            end
            remove_platform_pe_defaults(host, platform)
          end
        end

      end
    end
  end
end

