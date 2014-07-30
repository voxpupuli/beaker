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
    # @api dsl
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
      # If no host is defined as a 'master' and there is no 'default' host defined then
      # raise an error.
      #
      # @return [Array<Host>]
      # @raise [Beaker::DSL::Outcomes::FailTest] if there are less
      #   or more than 1 master is found.
      #
      # @example Basic usage
      #     on, master, 'cat /etc/puppet/puppet.conf'
      #
      def master
        find_only_one :master
      end

      # The host for which ['roles'] include 'database'
      #
      # @return [Array<Host>]
      # @raise [Beaker::DSL::Outcomes::FailTest] if there are less
      #   or more than 1 database is found.
      #
      # @example Basic usage
      #     on, agent, "curl -k http://#{database}:8080"
      #
      def database
        find_only_one :database
      end

      # The host for which ['roles'] include 'dashboard'
      #
      # @return [Array<Host>]
      # @raise [Beaker::DSL::Outcomes::FailTest] if there are less
      #   or more than 1 dashboard is found.
      #
      # @example Basic usage
      #     on, agent, "curl https://#{database}/nodes/#{agent}"
      #
      def dashboard
        find_only_one :dashboard
      end

      # The default host
      #   - if only one host defined, then that host
      #   OR
      #   - host with 'default' as a role
      #   OR
      #   - host with 'master' as a role
      #
      # @return [Array<Host>]
      # @raise [Beaker::DSL::Outcomes::FailTest] if no default host is found
      #
      # @example Basic usage
      #     on, default, "curl https://#{database}/nodes/#{agent}"
      #
      def default
        find_only_one :default
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
            if role !~ /\A[[:alpha:]]+[a-zA-Z0-9_]*[!?=]?\Z/
              raise "Role name format error for '#{role}'.  Allowed characters are: \na-Z\n0-9 (as long as not at the beginning of name)\n'_'\n'?', '!' and '=' (only as individual last character at end of name)"
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
      # @api public
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
      # @api public
      def hosts_as(desired_role = nil)
        hosts_with_role(hosts, desired_role)
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
    end
  end
end
