module Beaker
  module DSL
    module InstallUtils
      #
      # This module contains methods useful for both foss and pe installs
      #
      module PuppetUtils

        #Given a host construct a PATH that includes puppetbindir, facterbindir and hierabindir
        # @param [Host] host    A single host to construct pathing for
        def construct_puppet_path(host)
          path = (%w(puppetbindir facterbindir hierabindir)).compact.reject(&:empty?)
          #get the PATH defaults
          path.map! { |val| host[val] }
          path = path.compact.reject(&:empty?)
          #run the paths through echo to see if they have any subcommands that need processing
          path.map! { |val| echo_on(host, val) }

          separator = host['pathseparator']
          if not host.is_powershell?
            separator = ':'
          end
          path.join(separator)
        end

        #Append puppetbindir, facterbindir and hierabindir to the PATH for each host
        # @param [Host, Array<Host>, String, Symbol] hosts    One or more hosts to act upon,
        #                            or a role (String or Symbol) that identifies one or more hosts.
        def add_puppet_paths_on(hosts)
          block_on hosts do | host |
            host.add_env_var('PATH', construct_puppet_path(host))
          end
        end

        #Remove puppetbindir, facterbindir and hierabindir to the PATH for each host
        #
        # @param [Host, Array<Host>, String, Symbol] hosts    One or more hosts to act upon,
        #                            or a role (String or Symbol) that identifies one or more hosts.
        def remove_puppet_paths_on(hosts)
          block_on hosts do | host |
            host.delete_env_var('PATH', construct_puppet_path(host))
          end
        end

      end
    end
  end
end
