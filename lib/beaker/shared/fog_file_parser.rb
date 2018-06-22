require 'stringify-hash'

module Beaker
  module Shared
    # A set of functions to read .fog files
    module FogFileParser
      # Read a .fog file
      #
      # @note Loaded .fog files may use symbols for keys.
      #    Although not clearly documented, this *is* valid:
      #    https://www.rubydoc.info/gems/fog-core/1.42.0/Fog#credential-class_method
      #    https://github.com/fog/fog-core/blob/7865ef77ea990fd0d085e49c28e15957b7ce0d2b/spec/utils_spec.rb#L11
      #
      # @param fog_file_path [String] dot fog path. Overridden by
      # @return [StringifyHash] credentials stored in fog_file_path
      # @raise [ArgumentError] when the specified credential file is invalid, describing the reson
      def parse_fog_file(fog_file_path = '~/.fog', credential = :default)
        # respect credential location from env
        if ENV["FOG_RC"]
          fog_file_path = ENV["FOG_RC"]
          from_env = ' set in ENV["FOG_RC"]'
        end
        if !File.exist?(fog_file_path)
          raise ArgumentError, ".fog file '#{fog_file_path}'#{from_env} does not exist"
        end
        begin
          fog = YAML.load_file(fog_file_path)
        rescue Psych::SyntaxError => e
          raise ArgumentError, ".fog file '#{fog_file_path}'#{from_env} is not valid YAML:\n(#{e.class}) #{e.message}"
        end
        if fog == false # YAML.load => false for empty file
          raise ArgumentError, ".fog file '#{fog_file_path}'#{from_env} is empty"
        end
        # transparently support symbols or strings for keys
        fog = StringifyHash.new.merge!(fog)
        # respect credential from env
        # @note ENV must be a string, e.g. "default" not ":default"
        if ENV["FOG_CREDENTIAL"]
          credential = ENV["FOG_CREDENTIAL"].to_sym
        end
        if not fog[credential]
          raise ArgumentError, ".fog file #{fog_file_path}'#{from_env} is missing the required section: `#{credential}`"
        end
        fog[credential]
      end
    end
  end
end
