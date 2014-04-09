module Beaker
  module DSL
    #
    # Wrapping blocks in pre-built, standardized steps
    #
    # This is used to standardize beaker command creation and execution
    #
    # @api dsl
    module Patterns

      #Execute a block, using the provided host as a param
      #@param [Array<Host>, Host, String, Symbol] host A host role as a String or Symbol that can be
      #                                                used to search for a set of Hosts, or a {Host} 
      #                                                or Array<{Host}> to run the block against
      #@param [Block] block This method will yield to a block of code passed by the caller
      def block_on host, &block 
        result = nil
        if host.is_a? String or host.is_a? Symbol
          host = hosts_as(host) #check by role
        end
        if host.is_a? Array
          result = host.map do |h|
            block_on h, &block
          end
        else
          result = yield host
        end
        result
      end
    end
  end
end
