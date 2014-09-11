module Beaker
  class EC2Helper
    # Return a list of open ports for testing based on a hosts role
    #
    # @todo horribly hard-coded
    # @param [Array<String>] roles An array of roles
    # @return [Array<Number>] array of port numbers
    # @api private
    def self.amiports(roles)
      ports = [22, 61613, 8139, 8140]

      if roles.include? 'database'
        ports << 8080
        ports << 8081
      end

      if roles.include? 'dashboard'
        ports << 443
      end

      ports
    end
  end
end
