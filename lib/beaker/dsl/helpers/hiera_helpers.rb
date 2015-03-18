module Beaker
  module DSL
    module Helpers
      # Methods that help you interact with your hiera installation, hiera must be installed
      # for these methods to execute correctly
      module HieraHelpers

        # @!macro common_opts
        #   @param [Hash{Symbol=>String}] opts Options to alter execution.
        #   @option opts [Boolean] :silent (false) Do not produce log output
        #   @option opts [Array<Fixnum>] :acceptable_exit_codes ([0]) An array
        #     (or range) of integer exit codes that should be considered
        #     acceptable.  An error will be thrown if the exit code does not
        #     match one of the values in this list.
        #   @option opts [Hash{String=>String}] :environment ({}) These will be
        #     treated as extra environment variables that should be set before
        #     running the command.
        
        # Write hiera config file on one or more provided hosts
        #
        # @param[Host, Array<Host>, String, Symbol] host    One or more hosts to act upon,
        #                           or a role (String or Symbol) that identifies one or more hosts.
        # @param[Array] One or more hierarchy paths
        def write_hiera_config_on(host, hierarchy)

          block_on host do |host|
            hiera_config=Hash.new
            hiera_config[:backends] = 'yaml'
            hiera_config[:yaml] = {}
            hiera_config[:yaml][:datadir] = hiera_datadir(host)
            hiera_config[:hierarchy] = hierarchy
            hiera_config[:logger] = 'console'
            create_remote_file host, host.puppet['hiera_config'], hiera_config.to_yaml
          end
        end

        # Write hiera config file for the default host
        # @see #write_hiera_config_on
        def write_hiera_config(hierarchy)
          write_hiera_config_on(default, hierarchy)
        end

        # Copy hiera data files to one or more provided hosts
        #
        # @param[Host, Array<Host>, String, Symbol] host    One or more hosts to act upon,
        #                           or a role (String or Symbol) that identifies one or more hosts.
        # @param[String]            Directory containing the hiera data files.
        def copy_hiera_data_to(host, source)
          scp_to host, File.expand_path(source), hiera_datadir(host)
        end

        # Copy hiera data files to the default host
        # @see #copy_hiera_data_to
        def copy_hiera_data(source)
          copy_hiera_data_to(default, source)
        end

        # Get file path to the hieradatadir for a given host.
        # Handles whether or not a host is AIO-based & backwards compatibility
        #
        # @param[Host] host Host you want to use the hieradatadir from
        #
        # @return [String] Path to the hiera data directory
        def hiera_datadir(host)
          host[:type] =~ /aio/ ? File.join(host.puppet['codedir'], 'hieradata') : host[:hieradatadir]
        end

      end
    end
  end
end
