module Beaker
  module Options
    module HostsFileParser

      def self.parse_hosts_file(hosts_file_path)
        hosts_file_path = File.expand_path(hosts_file_path)
        unless File.exists?(hosts_file_path)
          raise ArgumentError, "Required host file '#{hosts_file_path}' does not exist!"
        end
        host_options = Beaker::Options::OptionsHash.new
        host_options = host_options.merge(YAML.load_file(hosts_file_path))

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
