module Beaker 
  module Shared
    #Methods for selecting host or hosts that match roles.
    module HostRoleParser

      #Find hosts from a given array of hosts that all have the desired role.
      #@param [Array<Host>] hosts The hosts to examine
      #@param [String] desired_role The hosts returned will have this role in their roles list
      #@return [Array<Host>] The hosts that have the desired role in their roles list
      def hosts_with_role(hosts, desired_role = nil)
        hosts.select do |host|
          desired_role.nil? or host['roles'].include?(desired_role.to_s)
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
    end
  end
end
