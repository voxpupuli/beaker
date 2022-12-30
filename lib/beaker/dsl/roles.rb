module Beaker
  module DSL
    #
    # Identifying hosts.
    #
    # This aids in reaching common subsets of hosts in a testing matrix.
    #
    # It requires the class it is mixed into to provide the attribute
    # `hosts` which contain the hosts to search, these should implement
    # {Beaker::Host}'s interface. They, at least, must have #[]
    # and #to_s available and provide an array when #[]('roles') is called.
    #
    # Also the constant {FailTest} needs to be defined it will be raised
    # in error conditions
    #
    module Roles

      # The hosts for which ['roles'] include 'agent'
      #
      # @return [Array<Host>] May be empty
      #
      # @example Basic usage
      #     agents.each do |agent|
      #       ...test each agent in turn...
      #     end
      #
      def agents
        hosts_as 'agent'
      end

      # The host for which ['roles'] include 'master'.
      # If no host has the 'master' role, then use the host defined as 'default'.
      # If no host is defined as a 'master' and there is no 'default' host defined
      # then it either raises an error (has a master),
      # or it returns nil (masterless)
      #
      # @return [Host] Returns the host, or nil if not found & masterless
      # @raise [Beaker::DSL::Outcomes::FailTest] if there are less
      #   or more than 1 master is found.
      #
      # @example Basic usage
      #     on, master, 'cat /etc/puppet/puppet.conf'
      #
      def master
        find_host_with_role :master
      end

      # The host for which ['roles'] include 'database'
      #
      # @return [Host] Returns the host, or nil if not found & masterless
      # @raise [Beaker::DSL::Outcomes::FailTest] if there are an inappropriate
      #   number of hosts found (depends on masterless option)
      #
      # @example Basic usage
      #     on, agent, "curl -k http://#{database}:8080"
      #
      def database
        find_host_with_role :database
      end

      # The host for which ['roles'] include 'dashboard'
      #
      # @return [Host] Returns the host, or nil if not found & masterless
      # @raise [Beaker::DSL::Outcomes::FailTest] if there are an inappropriate
      #   number of hosts found (depends on masterless option)
      #
      # @example Basic usage
      #     on, agent, "curl https://#{database}/nodes/#{agent}"
      #
      def dashboard
        find_host_with_role :dashboard
      end

      # The default host
      #   - if only one host defined, then that host
      #   OR
      #   - host with 'default' as a role
      #   OR
      #   - host with 'master' as a role
      #
      # @return [Host] Returns the host, or nil if not found & masterless
      # @raise [Beaker::DSL::Outcomes::FailTest] if there are an inappropriate
      #   number of hosts found (depends on masterless option)
      #
      # @example Basic usage
      #     on, default, "curl https://#{database}/nodes/#{agent}"
      #
      def default
        find_host_with_role :default
      end

      # Determine if host is not a controller, does not have roles 'master',
      # 'dashboard' or 'database'.
      #
      # @return [Boolean]      True if agent-only, false otherwise
      #
      # @example Basic usage
      #     if not_controller(host)
      #       puts "this host isn't in charge!"
      #     end
      #
      def not_controller(host)
        controllers = ['dashboard', 'database', 'master', 'console']
        matched_roles = host['roles'].select { |v| controllers.include?(v) }
        matched_roles.length == 0
      end

      # Determine if this host is exclusively an agent (only has a single role 'agent')
      #
      # @param [Host] host Beaker host to check
      #
      # @example Basic usage
      #     if agent_only(host)
      #       puts "this host is ONLY an agent!"
      #     end
      #
      # @return [Boolean]      True if agent-only, false otherwise
      def agent_only(host)
          host['roles'].length == 1 && host['roles'].include?('agent')
      end

      # Determine whether a host has an AIO version or not. If a host :pe_ver or
      # :version is not specified, then either the 'aio' role or type will be
      # needed for a host to be the AIO version.
      #
      # True if host has
      #   * PE version (:pe_ver) >= 4.0
      #   * FOSS version (:version) >= 4.0
      #   * the role 'aio'
      #   * the type 'aio'
      #
      # @note aio version is just a base-line condition.  If you want to check
      #   that a host is an aio agent, refer to {#aio_agent?}.
      #
      # @return [Boolean] whether or not a host is AIO-capable
      def aio_version?(host)
        [:pe_ver, :version].each do |key|
          version = host[key]
          return !version_is_less(version, '4.0') if version && !version.empty?
        end
        return true if host[:roles] && host[:roles].include?('aio')
        return true if host[:type] && /(\A|-)aio(\Z|-)/.match(host[:type])
        false
      end

      # Determine if the host is an AIO agent
      #
      # @param [Host] host Beaker host to check
      #
      # @return [Boolean] whether this host is an AIO agent or not
      def aio_agent?(host)
        aio_version?(host) && agent_only(host)
      end

      # Add the provided role to the host
      #
      # @param [Host] host Host to add role to
      # @param [String] role The role to add to host
      def add_role(host, role)
        host[:roles] = host[:roles] | [role]
      end

      #Create a new role method for a given arbitrary role name.  Makes it possible to be able to run
      #commands without having to refer to role by String or Symbol.  Will not add a new method
      #definition if the name is already in use.
      # @param [String, Symbol, Array[String,Symbol]] role The role that you wish to create a definition for, either a String
      # Symbol or an Array of Strings or Symbols.
      # @example Basic usage
      #  add_role_def('myrole')
      #  on myrole, "run command"
      def add_role_def role
        if role.kind_of?(Array)
          role.each do |r|
            add_role_def r
          end
        else
          if not respond_to? role
            if !/\A[[:alpha:]]+[a-zA-Z0-9_]*[!?=]?\Z/.match?(role)
              raise ArgumentError, "Role name format error for '#{role}'.  Allowed characters are: \na-Z\n0-9 (as long as not at the beginning of name)\n'_'\n'?', '!' and '=' (only as individual last character at end of name)"
            end
            self.class.send :define_method, role.to_s do
              hosts_with_role = hosts_as role.to_sym
              if hosts_with_role.length == 1
                hosts_with_role = hosts_with_role.pop
              end
              hosts_with_role
            end
          end
        end
      end

      # Determine if there is a host or hosts with the given role defined
      # @return [Boolean] True if there is a host with role, false otherwise
      #
      # @example Usage
      # if any_hosts_as?(:master)
      #   puts "master is defined"
      # end
      #
      def any_hosts_as?(role)
        hosts_as(role).length > 0
      end

      # Select hosts that include a desired role from #hosts
      #
      # @param [String, Symbol] desired_role The role to select for
      # @return [Array<Host>]                The hosts that match
      #                                      desired_role, may be empty
      #
      # @example Basic usage
      #     hairy = hosts_as :yak
      #     hairy.each do |yak|
      #       on yak, 'shave'
      #     end
      #
      def hosts_as(desired_role = nil)
        hosts_with_role(hosts, desired_role)
      end

      # finds the appropriate number of hosts for a given role
      # determines whether to allow no server using the masterless option
      #
      # @param [Symbol, String] role The role to find a host for
      # @return [Host] Returns the host, or nil if masterless and none are found
      #   for that role
      # @raise Throws an exception if an inappropriate number of hosts are found
      #   for that role
      def find_host_with_role role
        if (defined? options) && options[:masterless]
          find_at_most_one role
        else
          find_only_one role
        end
      end

      # @param [Symbol, String] role The role to find a host for
      # @return [Host] Returns the host, if one and only one is found
      # @raise Raises a failure exception if one and only one host that matches
      #   the specified role is NOT found.
      def find_only_one role
        only_host_with_role(hosts, role)
      rescue ArgumentError => e
        raise DSL::Outcomes::FailTest, e.to_s
      end

      # @param [Symbol, String] role The role to find a host for
      # @return [Host] Returns the host, or nil if not found
      # @raise Raises a failure exception if more than one host that matches
      #   the specified role is found.
      def find_at_most_one role
        find_at_most_one_host_with_role(hosts, role)
      rescue ArgumentError => e
        raise DSL::Outcomes::FailTest, e.to_s
      end
    end
  end
end
