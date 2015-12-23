module Beaker
  module DSL
    module InstallUtils
      #
      # This module contains methods useful for both foss and pe installs
      #
      module PuppetUtils

        #Given a type return an understood host type
        #@param [String] type The host type to be normalized
        #@return [String] The normalized type
        #
        #@example
        #  normalize_type('pe-aio')
        #    'pe'
        #@example
        #  normalize_type('git')
        #    'foss'
        #@example
        #  normalize_type('foss-internal')
        #    'foss'
        def normalize_type type
          case type
          when /(\A|-)(git)|(foss)(\Z|-)/
            'foss'
          when /(\A|-)pe(\Z|-)/
            'pe'
          when /(\A|-)aio(\Z|-)/
            'aio'
          else
            nil
          end
        end

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
            puppet_path = construct_puppet_path(host)
            host.add_env_var('PATH', puppet_path)
            host.add_env_var('PATH', 'PATH') # don't destroy the path!
          end
        end

        #Remove puppetbindir, facterbindir and hierabindir to the PATH for each host
        #
        # @param [Host, Array<Host>, String, Symbol] hosts    One or more hosts to act upon,
        #                            or a role (String or Symbol) that identifies one or more hosts.
        def remove_puppet_paths_on(hosts)
          block_on hosts do | host |
            puppet_path = construct_puppet_path(host)
            host.delete_env_var('PATH', puppet_path)
            host.add_env_var('PATH', 'PATH') # don't destroy the path!
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
            remove_defaults_on(host)

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

        # Configure the provided hosts to be of their host[:type], it host[type] == nil do nothing
        def configure_type_defaults_on( hosts )
          block_on hosts do |host|
            has_defaults = false
            if host[:type]
              host_type = host[:type]
              # clean up the naming conventions here (some teams use foss-package, git-whatever, we need
              # to correctly handle that
              # don't worry about aio, that happens in the aio_version? check
              host_type = normalize_type(host_type)
              if host_type and host_type !~ /aio/
                add_method = "add_#{host_type}_defaults_on"
                if self.respond_to?(add_method, host)
                  self.send(add_method, host)
                else
                  raise "cannot add defaults of type #{host_type} for host #{host.name} (#{add_method} not present)"
                end
                has_defaults = true
              end
            end
            if aio_version?(host)
              add_aio_defaults_on(host)
              has_defaults = true
            end
            # add pathing env
            if has_defaults
              add_puppet_paths_on(host)
            end
          end
        end
        alias_method :configure_foss_defaults_on, :configure_type_defaults_on
        alias_method :configure_pe_defaults_on, :configure_type_defaults_on

        #If the host is associated with a type remove all defaults and environment associated with that type.
        # @param [Host, Array<Host>, String, Symbol] hosts    One or more hosts to act upon,
        #                            or a role (String or Symbol) that identifies one or more hosts.
        def remove_defaults_on( hosts )
          block_on hosts do |host|
            if host['type']
              # clean up the naming conventions here (some teams use foss-package, git-whatever, we need
              # to correctly handle that
              # don't worry about aio, that happens in the aio_version? check
              host_type = normalize_type(host['type'])
              remove_puppet_paths_on(hosts)
              remove_method = "remove_#{host_type}_defaults_on"
              if self.respond_to?(remove_method, host)
                self.send(remove_method, host)
              else
                raise "cannot remove defaults of type #{host_type} associated with host #{host.name} (#{remove_method} not present)"
              end
              if aio_version?(host)
                remove_aio_defaults_on(host)
              end
            end
          end
        end

      end
    end
  end
end
