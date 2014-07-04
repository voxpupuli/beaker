module Beaker
  module Shared
    #Methods for managing Hosts.
    #- selecting hosts by role (Symbol or String)
    #- selecting hosts by name (String)
    #- adding additional method definitions for selecting by role
    #- executing blocks of code against selected sets of hosts
    module HostManager

      #Find hosts from a given array of hosts that all have the desired role.
      #@param [Array<Host>] hosts The hosts to examine
      #@param [String] desired_role The hosts returned will have this role in their roles list
      #@return [Array<Host>] The hosts that have the desired role in their roles list
      def hosts_with_role(hosts, desired_role = nil)
        hosts.select do |host|
          desired_role.nil? or host['roles'].include?(desired_role.to_s)
        end
      end

      #Find hosts from a given array of hosts that all have the desired name.
      #@param [Array<Host>] hosts The hosts to examine
      #@param [String] name The hosts returned will have this name
      #@return [Array<Host>] The hosts that have the desired name
      def hosts_with_name(hosts, name = nil)
        hosts.select do |host|
          name.nil? or host.name =~ /\A#{name}/
        end
      end

      #Find a single host with the role provided.  Raise an error if more than one host is found to have the
      #provided role.
      #@param [Array<Host>] hosts The hosts to examine
      #@param [String] role The host returned will have this role in its role list
      #@return [Host] The single host with the desired role in its roles list
      #@raise [ArgumentError] Raised if more than one host has the given role defined, or if no host has the
      #                       role defined.
      def only_host_with_role(hosts, role)
        a_host = hosts_with_role(hosts, role)
        case
          when a_host.length == 0
            raise ArgumentError, "There should be one host with #{role} defined!"
          when a_host.length > 1
            host_string = ( a_host.map { |host| host.name } ).join( ', ')
            raise ArgumentError, "There should be only one host with #{role} defined, but I found #{a_host.length} (#{host_string})"
        end
        a_host.first
      end

      #Create a new role method for a given arbitrary role name.  Makes it possible to be able to run
      #commands without having to refer to role by String or Symbol.
      # @param [String, Symbol] role The role that you wish to create a definition for
      # @example Basic usage
      #  add_role_def('myrole')
      #  on myrole, "run command"
      def add_role_def role
        send :define_method, role do
          hosts_with_role role
        end
      end

      #Execute a block selecting the hosts that match with the provided criteria
      #@param [Array<Host>, Host, String, Symbol] sorter A host role as a String or Symbol that can be
      #                                                used to search for a set of Hosts,  a host name
      #                                                as a String that can be used to search for
      #                                                a set of Hosts, or a {Host}
      #                                                or Array<{Host}> to run the block against
      #@param [Array<Host>] hosts ([]) The hosts to sort through. Defaults to the empty Array.
      #@param [Block] block This method will yield to a block of code passed by the caller
      def run_block_on sorter, hosts = [], &block
        result = nil
        if sorter.is_a? String or sorter.is_a? Symbol
          if not hosts.empty?
            match = hosts_with_role(hosts, sorter) #check by role
            if match.empty?
              match = hosts_with_name(hosts, sorter) #check by name
            end
            sorter = match
          else
            raise ArgumentError, "Unable to sort for #{sorter} type hosts when provided with [] as Hosts"
          end
        end
        if sorter.is_a? Array
          result = sorter.map do |s|
            run_block_on s, hosts, &block
          end
        else
          result = yield sorter
        end
        result
      end

    end
  end
end
