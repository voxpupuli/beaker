module Beaker
  module DSL
    # These are simple patterns that appear frequently in beaker test
    # code, and are provided to simplify test construction.
    #
    #
    # It requires the class it is mixed into to provide the attribute
    # `hosts` which contain the hosts to search, these should implement
    # {Beaker::Host}'s interface. They, at least, must have #[]
    # and #to_s available and provide an array when #[]('roles') is called.
    #
    module Patterns

      # Execute a block selecting the hosts that match with the provided criteria
      # @param [Array<Host>, Host, String, Symbol] hosts_or_filter A host role as a String or Symbol that can be
      #                                                used to search for a set of Hosts,  a host name
      #                                                as a String that can be used to search for
      #                                                a set of Hosts, or a {Host}
      #                                                or Array<{Host}> to run the block against
      # @param [Block] block This method will yield to a block of code passed by the caller
      #
      # @return [Array<Result>, Result] An array of results, or a result object.
      #   Check {#run_block_on} for more details on this.
      def block_on hosts_or_filter, &block
        block_hosts = nil
        if defined? hosts
          block_hosts = hosts
        end
        filter = nil
        if hosts_or_filter.is_a? String or hosts_or_filter.is_a? Symbol
          filter = hosts_or_filter
        else
          block_hosts = hosts_or_filter
        end
        run_block_on block_hosts, filter, &block
      end

    end
  end
end
