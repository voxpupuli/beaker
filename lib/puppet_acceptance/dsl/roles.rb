module PuppetAcceptance
  module DSL
    #
    # Identify hosts
    #
    # This module holds methods to mix into a test case that provide
    # methods to reach common subsets of hosts in a testing matrix
    #
    # It requires the class it is mixed into to provide 1 attribute:
    # 1. hosts   --  which contain the hosts to search, these must have #[]
    #    and #to_s available and provide an array when #['roles'] is called
    #
    # Also PuppetAcceptance::FailTest needs to be defined (it will be raised
    #   in error conditions
    #
    # @api dsl
    module Roles

      # The hosts for which ['roles'] include 'agent'
      #
      # @return [Array<Host>] May be empty
      def agents
        hosts_as 'agent'
      end

      # The host for which ['roles'] include 'master'
      #
      # @return [Array<Host>]
      # @raise [PuppetAcceptance::FailTest] if there are less or more
      #                                     than 1 master found
      def master
        find_only_one :master
      end

      # The host for which ['roles'] include 'database'
      #
      # @return [Array<Host>]
      # @raise [PuppetAcceptance::FailTest] if there are less or more
      #                                     than 1 database found
      def database
        find_only_one :database
      end

      # The host for which ['roles'] include 'dashboard'
      #
      # @return [Array<Host>]
      # @raise [PuppetAcceptance::FailTest] if there are less or more
      #                                     than 1 dashboard found
      def dashboard
        find_only_one :dashboard
      end

      # Select hosts that include a desired role from #hosts
      #
      # @param [String, Symbol] desired_role The role to select for
      # @return [Array<Host>]                The hosts that match
      #                                      desired_role, may be empty
      # @api public
      def hosts_as(desired_role = nil)
        hosts.select do |host|
          desired_role.nil? or host['roles'].include?(desired_role.to_s)
        end
      end

      # @param [Symbol, String] role The role to find a host for
      # @return [Host] Returns the host, if one and only one is found
      # @raise [PuppetAcceptance::FailTest] Raises a failure exception if one
      #                                     and only one host that matches
      #                                     the specified role is NOT found.
      def find_only_one role
        a_host = hosts_as( role )
        raise PuppetAcceptance::FailTest,
          "There can be only one #{role}, but I found:" +
          "#{a_host.map {|h| h.to_s } }" unless a_host.length == 1
        a_host.first
      end
    end
  end
end
