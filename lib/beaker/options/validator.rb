module Beaker
  module Options

    class Validator
      VALID_FAIL_MODES              = /stop|fast|slow/
      VALID_PRESERVE_HOSTS          = /always|onfail|onpass|never/
      FRICTIONLESS_ROLE             = 'frictionless'
      FRICTIONLESS_ADDITIONAL_ROLES = %w(master database dashboard console)

      # Determine is a given file exists and is a valid YAML file
      # @param [String] f The YAML file path to examine
      # @param [String] msg An options message to report in case of error
      # @raise [ArgumentError] Raise if file does not exist or is not valid YAML
      def check_yaml_file(f, msg = '')
        validator_error "#{f} does not exist (#{msg})" unless File.file?(f)

        begin
          YAML.load_file(f)
        rescue Beaker::Options::Parser::PARSE_ERROR => e
          validator_error "#{f} is not a valid YAML file (#{msg})\n\t#{e}"
        end
      end

      # resolves all file symlinks that require it.
      #
      # @param [Beaker::OptionsHash] options Beaker Options hash
      # @note doing it here allows us to not need duplicate logic, which we
      #   would need if we were doing it in the parser (--hosts & --config)
      #
      # @return nil
      # @api public
      def resolve_symlinks(options)
        options[:hosts_file] = File.realpath(options[:hosts_file]) if options[:hosts_file]
      end

      # Raises an ArgumentError with associated message
      # @param [String] msg The error message to be reported
      # @raise [ArgumentError] Takes the supplied message and raises it as an ArgumentError
      def validator_error(msg = '')
        raise ArgumentError, msg.to_s
      end

      # alias to keep old methods and functionality from throwing errors.
      alias_method :parser_error, :validator_error

      # Raises an ArgumentError if more than one default exists,
      # otherwise returns true or false if default is set.
      #
      # @param [Array<String>] default list of host names
      # @return [true, false]
      # @thr
      def default_set?(default)
        if default.empty?
          return false
        elsif default.length > 1
          validator_error "Only one host may have the role 'default', default roles assigned to #{default}"
        end

        true
      end

      # Raises an error if fail_mode is not a supported failure mode.
      #
      # @param [String] fail_mode Failure mode setting
      # @return [nil] Does not return anything
      def valid_fail_mode?(fail_mode)
        #check for valid fail mode
        if fail_mode !~ VALID_FAIL_MODES
          validator_error "--fail-mode must be one of fast or slow, not '#{fail_mode}'"
        end
      end

      # Raises an error if hosts_setting is not a supported preserve hosts value.
      #
      # @param [String] hosts_setting Preserve hosts setting
      # @return [nil] Does not return anything
      def valid_preserve_hosts?(hosts_setting)
        #check for valid preserve_hosts option
        if hosts_setting !~ VALID_PRESERVE_HOSTS
          validator_error("--preserve_hosts must be one of always, onfail, onpass or never, not '#{hosts_setting}'")
        end
      end

      # Raise an error if host does not have a platform defined.
      #
      # @param [::Beaker::Host] host A beaker host
      # @param [String] name Host name
      # @return [nil] Does not return anything
      def has_platform?(host, name)
        unless host['platform']
          validator_error "Host #{name} does not have a platform specified"
        end
      end

      # Raise an error if an item exists in both the include and exclude lists.
      #
      # @param [Array] include included items
      # @param [Array] exclude excluded items
      # @return [nil] Does not return anything
      def validate_tags(include, exclude)

        include.each do |included_tag|
          # select items from exclude set that match included_tag
          # no match is an empty list/array/[]
          if exclude.select { |ex| ex == included_tag } != []
            validator_error "tag '#{included_tag}' cannot be in both the included and excluded tag sets"
          end
        end

      end

      def valid_frictionless_roles?(role_array)
        if role_array.include?(FRICTIONLESS_ROLE) and !(role_array & FRICTIONLESS_ADDITIONAL_ROLES).empty?
          validator_error "Only agent nodes may have the role 'frictionless'."
        end
      end

      # Raise an error if the master count is incorrect.
      #
      # @param [Integer] count Count of roles with 'master'
      # @return [nil] Nothing is returned
      def valid_master_count?(count)
        if count > 1
          validator_error("Only one host/node may have the role 'master'.")
        end

      end

    end

  end
end
