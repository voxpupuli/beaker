module Beaker
  module DSL
    module Helpers
      # Methods that help you interact with your facter installation, facter must be installed
      # for these methods to execute correctly
      #
      module FacterHelpers

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
        #

        # Get a facter fact from a provided host
        #
        # @param [Host, Array<Host>, String, Symbol] host    One or more hosts to act upon,
        #                            or a role (String or Symbol) that identifies one or more hosts.
        # @param [String] name The name of the fact to query for
        # @!macro common_opts
        #
        # @return String The value of the fact 'name' on the provided host
        # @raise  [FailTest] Raises an exception if call to facter fails
        def fact_on(host, name, opts = {})
          result = on host, facter(name, opts)
          if result.kind_of?(Array)
            result.map { |res| res.stdout.chomp }
          else
            result.stdout.chomp
          end
        end

        # Get a facter fact from the default host
        # @see #fact_on
        def fact(name, opts = {})
          fact_on(default, name, opts)
        end

      end
    end
  end
end
