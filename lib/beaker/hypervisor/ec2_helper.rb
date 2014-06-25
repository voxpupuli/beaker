module Beaker
  class EC2Helper
    # Return a list of open ports for testing based on a hosts role
    #
    # @todo horribly hard-coded
    # @param [Array<String>] roles An array of roles
    # @return [Array<Number>] array of port numbers
    # @api private
    def self.amiports(roles, *ports)
      amiports = [22]

      if roles.include? 'database'
        amiports << 8080
        amiports << 8081
      end

      if roles.include? 'master'
        amiports << 8140
      end

      if roles.include? 'dashboard'
        amiports << 443
      end

      amiports << ports
      amiports.flatten
    end
  end
end
