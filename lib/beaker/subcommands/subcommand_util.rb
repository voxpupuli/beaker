require 'json'
require 'stringio'
require 'yaml/store'
require 'fileutils'

module Beaker
  module Subcommands
    # Methods used in execution of Subcommands
    # - should we execute a subcommand?
    # - sanitize options for saving as json
    # - exit with a specific message
    # - capture stdout and stderr
    module SubcommandUtil
      CONFIG_DIR = ".beaker"
      SUBCOMMAND_OPTIONS = Pathname("#{CONFIG_DIR}/subcommand_options.yaml")
      SUBCOMMAND_STATE = Pathname("#{CONFIG_DIR}/.subcommand_state.yaml")
      PERSISTED_HOSTS = Pathname("#{CONFIG_DIR}/.hosts.yaml")
      PERSISTED_HYPERVISORS = Pathname("#{CONFIG_DIR}/.hypervisors.yaml")
      # These options should not be part of persisted subcommand state
      UNPERSISTED_OPTIONS = [:beaker_version, :command_line, :hosts_file, :logger, :password_prompt, :timestamp]

      def self.execute_subcommand?(arg0)
        return false if arg0.nil?
        (Beaker::Subcommand.instance_methods(false) << :help).include? arg0.to_sym
      end

      def self.prune_unpersisted(options)
        UNPERSISTED_OPTIONS.each do |unpersisted_key|
          options.each do |key, value|
            if key == unpersisted_key
              options.delete(key)
            elsif value.is_a?(Hash)
              options[key] = self.prune_unpersisted(value) unless value.empty?
            end
          end
        end
        options
      end

      def self.sanitize_options_for_save(options)
        # God help us, the YAML library won't stop adding tags to objects, so this
        # hack is a way to force the options into the basic object types so that
        # an eventual YAML.dump or .to_yaml call doesn't add tags.
        # Relevant stackoverflow: http://stackoverflow.com/questions/18178098/how-do-i-have-ruby-yaml-dump-a-hash-subclass-as-a-simple-hash
        JSON.parse(prune_unpersisted(options).to_json)
      end

      # Print a message to the console and exit with specified exit code, defaults to 1
      # @param [String] msg the message to output
      # @param [Hash<Object>] options to specify exit code or output stack trace
      def self.error_with(msg, options={})
        puts msg
        puts options[:stack_trace] if options[:stack_trace]
        exit_code = options[:exit_code] ? options[:exit_code] : 1
        exit(exit_code)
      end

      # Execute a task but capture stdout and stderr to a buffer
      def self.with_captured_output
        begin
          old_stdout = $stdout.clone
          old_stderr = $stderr.clone
          $stdout = StringIO.new
          $stderr = StringIO.new
          yield
        ensure
          $stdout = old_stdout
          $stderr = old_stderr
        end
      end

    end
  end
end
