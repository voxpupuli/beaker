require 'stringify-hash'

module Beaker
  module Shared
    # A set of functions to read .fog files
    module FogCredentials
      # Constructs ArgumentError with common phrasing for #get_fog_credentials errors
      #
      # @param path [String] path to offending file
      # @param from_env [String] if the path was overridden in ENV
      # @param reason [String] explanation for the failure
      # @return [ArgumentError] ArgumentError with preformatted message
      def fog_credential_error(path = nil, from_env = nil, reason = nil)
        message = "Failed loading credentials from .fog file"
        message << " '#{path}'" if path
        message << " #{from_env}" if from_env
        message << "."
        message << "Reason: #{reason}" if reason
        ArgumentError.new(message)
      end

      # Load credentials from a .fog file
      #
      # @note Loaded .fog files may use symbols for keys.
      #    Although not clearly documented, it is valid:
      #    https://www.rubydoc.info/gems/fog-core/1.42.0/Fog#credential-class_method
      #    https://github.com/fog/fog-core/blob/7865ef77ea990fd0d085e49c28e15957b7ce0d2b/spec/utils_spec.rb#L11
      #
      # @param fog_file_path [String] dot fog path. Overridden by ENV["FOG_RC"]
      # @param credential_group [String, Symbol] Credential group to use. Overridden by ENV["FOG_CREDENTIAL"]
      # @return [StringifyHash] credentials stored in fog_file_path
      # @raise [ArgumentError] when the credentials cannot be loaded, describing the reson
      def get_fog_credentials(fog_file_path = '~/.fog', credential_group = :default)
        # respect file location from env
        if ENV["FOG_RC"]
          fog_file_path = ENV["FOG_RC"]
          from_env = ' set in ENV["FOG_RC"]'
        end
        begin
          fog = YAML.load_file(fog_file_path)
        rescue Psych::SyntaxError, Errno::ENOENT => e
          raise fog_credential_error fog_file_path, from_env, "(#{e.class}) #{e.message}"
        end
        if fog == false # YAML.load => false for empty file
          raise fog_credential_error fog_file_path, from_env, "is empty."
        end
        # transparently support symbols or strings for keys
        fog = StringifyHash.new.merge!(fog)
        # respect credential from env
        # @note ENV must be a string, e.g. "default" not ":default"
        if ENV["FOG_CREDENTIAL"]
          credential_group = ENV["FOG_CREDENTIAL"].to_sym
        end
        if not fog[credential_group]
          raise fog_credential_error fog_file_path, from_env, "could not load the specified credential group '#{credential_group}'."
        end
        fog[credential_group]
      end
    end
  end
end
