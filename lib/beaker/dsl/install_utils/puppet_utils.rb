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
            host.add_env_var('PATH', 'PATH') # don't destroy the path!
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

        #Configure the provided hosts to be of the provided type (one of foss, aio, pe), if the host
        #is already associated with a type then remove the previous settings for that type
        # @param [Host, Array<Host>, String, Symbol] hosts    One or more hosts to act upon,
        #                            or a role (String or Symbol) that identifies one or more hosts.
        # @param [String] type One of 'aio', 'pe' or 'foss'
        def configure_defaults_on( hosts, type )
          block_on hosts do |host|
            # check to see if the host already has a type associated with it
            if host['type']
              remove_puppet_paths_on(hosts)
              remove_method = "remove_#{host['type']}_defaults_on"
              if self.respond_to?(remove_method, host)
                self.send(remove_method, host)
              else
                raise "cannot remove defaults of type #{host['type']} associated with host #{host.name} (#{remove_method} not present)"
              end
            end
            add_method = "add_#{type}_defaults_on"
            if self.respond_to?(add_method, host)
              self.send(add_method, host)
            else
              raise "cannot add defaults of type #{type} for host #{host.name} (#{add_method} not present)"
            end
            # add pathing env
            add_puppet_paths_on(host)
          end
        end

      end
    end
  end
end
