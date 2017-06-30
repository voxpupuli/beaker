module Beaker
  class EC2Helper
    # Return a list of open ports for testing based on a hosts role
    #
    # @todo horribly hard-coded
    # @param [Host] host to find ports for
    # @return [Array<Number>] array of port numbers
    # @api private
    def self.amiports(host)
      ports = [22, 61613, 8139]

      roles = host['roles']

      if roles.include? 'database'
        ports << 5432
        ports << 8080
        ports << 8081
      end

      if roles.include? 'master'
        ports << 8140
        ports << 8142
      end

      if roles.include? 'dashboard'
        ports << 443
        ports << 4433
        ports << 4435
      end

      # If they only specified one port in the host config file, YAML will have converted it
      # into a string, but if it was more than one, an array.
      user_ports = []
      if host.has_key?('additional_ports')
        user_ports = host['additional_ports'].is_a?(Array) ? host['additional_ports'] : [host['additional_ports']]
      end

      additional_ports = ports + user_ports
      additional_ports.uniq
    end
  end
end
