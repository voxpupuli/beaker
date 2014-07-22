module Beaker
  module Options
    #A set of functions to parse hosts files
    module HostsFileParser

      # Read the contents of the hosts.cfg into an OptionsHash, merge the 'CONFIG' section into the OptionsHash, return OptionsHash
      # @param [String] hosts_file_path The path to the hosts file
      #
      # @example
      #     hosts_hash = HostsFileParser.parse_hosts_file('sample.cfg')
      #     hosts_hash == {:HOSTS=>{:"pe-ubuntu-lucid"=>{:roles=>["agent", "dashboard", "database", "master"], ... }
      #
      # @return [OptionsHash] The contents of the hosts file as an OptionsHash
      # @raise [ArgumentError] Raises if hosts_file_path is not a path to a file, or is not a valid YAML file
      def self.parse_hosts_file(hosts_file_path = nil)
        host_options = Beaker::Options::OptionsHash.new
        host_options['HOSTS'] ||= {}
        unless hosts_file_path
           return host_options
        end
        hosts_file_path = File.expand_path(hosts_file_path)
        unless File.exists?(hosts_file_path)
          raise ArgumentError, "Host file '#{hosts_file_path}' does not exist!"
        end
        begin
          host_options = host_options.merge(YAML.load_file(hosts_file_path))
        rescue Psych::SyntaxError => e
          raise ArgumentError, "#{hosts_file_path} is not a valid YAML file\n\t#{e}"
        end

        # Make sure the roles array is present for all hosts
        host_options['HOSTS'].each_key do |host|
          host_options['HOSTS'][host]['roles'] ||= []
        end
        if host_options.has_key?('CONFIG')
          host_options = host_options.merge(host_options.delete('CONFIG'))
        end
        host_options
      end

    end
  end
end
