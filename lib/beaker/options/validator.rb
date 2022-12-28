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
      def validate_fail_mode(fail_mode)
        #check for valid fail mode
        unless fail_mode.is_a?(String) && VALID_FAIL_MODES.match?(fail_mode)
          validator_error "--fail-mode must be one of fast or slow, not '#{fail_mode}'"
        end
      end

      # Raises an error if hosts_setting is not a supported preserve hosts value.
      #
      # @param [String] hosts_setting Preserve hosts setting
      # @return [nil] Does not return anything
      def validate_preserve_hosts(hosts_setting)
        #check for valid preserve_hosts option
        unless hosts_setting.is_a?(String) && VALID_PRESERVE_HOSTS.match?(hosts_setting)
          validator_error("--preserve_hosts must be one of always, onfail, onpass or never, not '#{hosts_setting}'")
        end
      end

      # Raise an error if host does not have a platform defined.
      #
      # @param [::Beaker::Host] host A beaker host
      # @param [String] name Host name
      # @return [nil] Does not return anything
      def validate_platform(host, name)
        if !host['platform'] || host['platform'].empty?
          validator_error "Host #{name} does not have a platform specified"
        end
      end

      # Raise an error if an item exists in both the include and exclude lists.
      #
      # @note see test tagging logic at {Beaker::DSL::TestTagging} module
      #
      # @param [Array] tags_and included items
      # @param [Array] tags_exclude excluded items
      # @return [nil] Does not return anything
      def validate_test_tags(tags_and, tags_or, tags_exclude)
        if tags_and.length > 0 && tags_or.length > 0
          validator_error "cannot have values for both test tagging operands (AND and OR)"
        end

        tags_and.each do |included_tag|
          # select items from exclude set that match included_tag
          # no match is an empty list/array/[]
          if tags_exclude.select { |ex| ex == included_tag } != []
            validator_error "tag '#{included_tag}' cannot be in both the included and excluded tag sets"
          end
        end
      end

      # Raises an error if role_array contains the frictionless role and conflicting roles.
      #
      # @param [Array<String>] role_array List of roles
      # @raise [ArgumentError] Raises if role_array contains conflicting roles
      def validate_frictionless_roles(role_array)
        if role_array.include?(FRICTIONLESS_ROLE) and !(role_array & FRICTIONLESS_ADDITIONAL_ROLES).empty?
          validator_error "Only agent nodes may have the role 'frictionless'."
        end
      end

      # Raise an error if the master count is incorrect.
      #
      # @param [Integer] count Count of roles with 'master'
      # @return [nil] Nothing is returned
      # @raise [ArgumentError] Raises if master count is greater than 1
      def validate_master_count(count)
        if count > 1
          validator_error("Only one host/node may have the role 'master'.")
        end
      end

      # Raise an error if file_list is empty
      #
      # @param [Array<String>] file_list list of files
      # @param [String] path file path to report in error
      # @raise [ArgumentError] Raises if file_list is empty
      def validate_files(file_list, path)
        if file_list.empty?
          validator_error("No files found for path: '#{path}'")
        end
      end

      # Raise an error if path is not a valid file or directory
      #
      # @param [String] path File path
      # @raise [ArgumentError] Raises if path is not a valid file or directory
      def validate_path(path)
        if !File.file?(path) && !File.directory?(path)
          validator_error("#{path} used as a file option but is not a file or directory!")
        end
      end
    end
  end
end
