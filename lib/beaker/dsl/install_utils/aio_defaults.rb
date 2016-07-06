module Beaker
  module DSL
    module InstallUtils
      #
      # This module contains default values for aio paths and directorys per-platform
      #
      module AIODefaults

        #Here be the pathing and default values for AIO installs
        #
        AIO_DEFAULTS = {
          'unix' => {
            'puppetbindir'          => '/opt/puppetlabs/bin',
            'privatebindir'         => '/opt/puppetlabs/puppet/bin',
            'distmoduledir'         => '/etc/puppetlabs/code/modules',
            'sitemoduledir'         => '/opt/puppetlabs/puppet/modules',
          },
          'windows' => { #windows
            'puppetbindir'      => '/cygdrive/c/Program Files (x86)/Puppet Labs/Puppet/bin:/cygdrive/c/Program Files/Puppet Labs/Puppet/bin',
            'privatebindir'     => '/cygdrive/c/Program Files (x86)/Puppet Labs/Puppet/sys/ruby/bin:/cygdrive/c/Program Files/Puppet Labs/Puppet/sys/ruby/bin',
            'distmoduledir'     => '`cygpath -smF 35`/PuppetLabs/code/modules',
            # sitemoduledir not included (check PUP-4049 for more info)
          },
          'pwindows' => { #pure windows
            'puppetbindir'      => '"C:\\Program Files (x86)\\Puppet Labs\\Puppet\\bin";"C:\\Program Files\\Puppet Labs\\Puppet\\bin"',
            'privatebindir'     => '"C:\\Program Files (x86)\\Puppet Labs\\Puppet\\sys\\ruby\\bin";"C:\\Program Files\\Puppet Labs\\Puppet\\sys\\ruby\\bin"',
            'distmoduledir'     => 'C:\\ProgramData\\PuppetLabs\\code\\modules',
          }
        }

        # Add the appropriate aio defaults to the host object so that they can be accessed using host[option], set host[:type] = aio
        # @param [Host] host    A single host to act upon
        # @param [String] platform The platform type of this host, one of windows or unix
        def add_platform_aio_defaults(host, platform)
          AIO_DEFAULTS[platform].each_pair do |key, val|
            host[key] = val
          end
          # add group and type here for backwards compatability
          if host['platform'] =~ /windows/
            host['group'] = 'Administrators'
          else
            host['group'] = 'puppet'
          end
        end

        # Add the appropriate aio defaults to an array of hosts
        # @param [Host, Array<Host>, String, Symbol] hosts    One or more hosts to act upon,
        #                            or a role (String or Symbol) that identifies one or more hosts.
        def add_aio_defaults_on(hosts)
          block_on hosts do | host |
            if host.is_powershell?
              platform = 'pwindows'
            elsif host['platform'] =~ /windows/
              platform = 'windows'
            else
              platform = 'unix'
            end
            add_platform_aio_defaults(host, platform)
          end
        end

        # Remove the appropriate aio defaults from the host object so that they can no longer be accessed using host[option], set host[:type] = nil
        # @param [Host] host    A single host to act upon
        # @param [String] platform The platform type of this host, one of windows, pswindows, freebsd, mac & unix
        def remove_platform_aio_defaults(host, platform)
          AIO_DEFAULTS[platform].each_pair do |key, val|
            host.delete(key)
          end
          host['group'] = nil
        end

        # Remove the appropriate aio defaults from an array of hosts
        # @param [Host, Array<Host>, String, Symbol] hosts    One or more hosts to act upon,
        #                            or a role (String or Symbol) that identifies one or more hosts.
        def remove_aio_defaults_on(hosts)
          block_on hosts do | host |
            if host.is_powershell?
              platform = 'pswindows'
            elsif host['platform'] =~ /windows/
              platform = 'windows'
            else
              platform = 'unix'
            end
            remove_platform_aio_defaults(host, platform)
          end
        end


      end
    end
  end
end

