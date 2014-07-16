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

      #Execute a block selecting the hosts that match with the provided criteria
      #@param [Array<Host>, Host] hosts The host or hosts to run the provided block against
      #@param [String, Symbol] filter Optional filter to apply to provided hosts - limits by name or role
      #@param [Block] block This method will yield to a block of code passed by the caller
      def run_block_on hosts = [], filter = nil, &block
        result = nil
        block_hosts = hosts #the hosts to apply the block to after any filtering
        if filter
          if not hosts.empty?
            block_hosts = hosts_with_role(hosts, filter) #check by role
            if block_hosts.empty?
              block_hosts = hosts_with_name(hosts, filter) #check by name
            end
            if block_hosts.length == 1  #we only found one matching host, don't need it wrapped in an array
              block_hosts = block_hosts.pop
            end
          else
            raise ArgumentError, "Unable to sort for #{filter} type hosts when provided with [] as Hosts"
          end
        end
        if block_hosts.is_a? Array
          result = block_hosts.map do |h|
            run_block_on h, nil, &block
          end
        else
          result = yield block_hosts
        end
        result
      end

    end
  end
end
