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

      #Find hosts from a given array of hosts that all have the desired name, match against host name,
      #vmhostname and ip (the three valid ways to identify an individual host)
      #@param [Array<Host>] hosts The hosts to examine
      #@param [String] name The hosts returned will have this name/vmhostname/ip
      #@return [Array<Host>] The hosts that have the desired name/vmhostname/ip
      def hosts_with_name(hosts, name = nil)
        hosts.select do |host|
          name.nil? or host.name =~ /\A#{name}/ or host[:vmhostname] =~ /\A#{name}/ or host[:ip] =~ /\A#{name}/
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

      # Find at most a single host with the role provided.  Raise an error if
      # more than one host is found to have the provided role.
      # @param [Array<Host>] hosts The hosts to examine
      # @param [String] role The host returned will have this role in its role list
      # @return [Host] The single host with the desired role in its roles list
      #                     or nil if no host is found
      # @raise [ArgumentError] Raised if more than one host has the given role defined
      def find_at_most_one_host_with_role(hosts, role)
        role_hosts = hosts_with_role(hosts, role)
        host_with_role = nil
        case role_hosts.length
        when 0
        when 1
          host_with_role = role_hosts[0]
        else
          host_string = ( role_hosts.map { |host| host.name } ).join( ', ')
          raise ArgumentError, "There should be only one host with #{role} defined, but I found #{role_hosts.length} (#{host_string})"
        end
        host_with_role
      end

      # Execute a block selecting the hosts that match with the provided criteria
      #
      # @param [Array<Host>, Host] hosts The host or hosts to run the provided block against
      # @param [String, Symbol] filter Optional filter to apply to provided hosts - limits by name or role
      # @param [Block] block This method will yield to a block of code passed by the caller
      #
      # @todo beaker3.0: simplify return types to Array<Result> only
      #
      # @return [Array<Result>, Result] If a non-empty array of hosts has been
      #   passed (after filtering), then an array of results is returned. Else,
      #   a result object is returned.
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
          if block_hosts.length > 0
            result = block_hosts.map do |h|
              run_block_on h, nil, &block
            end
          else
            # there are no matching hosts to execute against
            # should warn here
            # check if logger is defined in this context
            if ( cur_logger = (logger || @logger ) )
              cur_logger.warn "Attempting to execute against an empty array of hosts (#{hosts}, filtered to #{block_hosts}), no execution will occur"
            end
          end
        else
          result = yield block_hosts
        end
        result
      end

    end
  end
end
