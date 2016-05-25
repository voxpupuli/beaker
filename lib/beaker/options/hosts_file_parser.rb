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
      # @raise [ArgumentError] Raises if hosts_file_path is not a valid YAML file
      # @raise [Errno::ENOENT] File not found error: hosts_file doesn't exist
      def self.parse_hosts_file(hosts_file_path = nil)
        host_options = new_host_options
        return host_options unless hosts_file_path
        error_message = "#{hosts_file_path} is not a valid YAML file\n\t"
        host_options = self.merge_hosts_yaml( host_options, error_message ) {
          hosts_file_path = File.expand_path( hosts_file_path )
          YAML.load_file( hosts_file_path )
        }
        fix_roles_array( host_options )
      end

      # Read the contents of a host definition as a string into an OptionsHash
      #
      # @param [String] hosts_def_yaml YAML hosts definition
      #
      # @return [OptionsHash] Contents of the hosts file as an OptionsHash
      # @raise [ArgumentError] If hosts_def_yaml is not a valid YAML string
      def self.parse_hosts_string(hosts_def_yaml = nil)
        host_options = new_host_options
        return host_options unless hosts_def_yaml
        error_message = "#{hosts_def_yaml}\nis not a valid YAML string\n\t"
        host_options = self.merge_hosts_yaml( host_options, error_message ) {
          YAML.load( hosts_def_yaml )
        }
        fix_roles_array( host_options )
      end

      # Convenience method to create new OptionsHashes with a HOSTS section
      #
      # @return [OptionsHash] Hash with HOSTS section
      def self.new_host_options
        host_options = Beaker::Options::OptionsHash.new
        host_options['HOSTS'] ||= {}
        host_options
      end

      # Make sure the roles array is present for all hosts
      #
      def self.fix_roles_array( host_options )
        host_options['HOSTS'].each_key do |host|
          host_options['HOSTS'][host]['roles'] ||= []
        end
        if host_options.has_key?('CONFIG')
          host_options = host_options.merge(host_options.delete('CONFIG'))
        end
        host_options
      end

      # Merges YAML read in the passed block into given OptionsHash
      #
      # @param [OptionsHash] host_options Host information hash
      # @param [String] error_message Message to print if {::Psych::SyntaxError}
      #   is raised during block execution
      # @return [OptionsHash] Updated host_options with host info merged
      def self.merge_hosts_yaml( host_options, error_message, &block )
        begin
          loaded_host_options = yield
        rescue Psych::SyntaxError => e
          error_message << e.to_s
          raise ArgumentError, error_message
        end

        host_options.merge( loaded_host_options )
      end

    end
  end
end
