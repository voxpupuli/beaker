module Beaker
  module Shared
    # Methods for parsing options.
    module OptionsResolver
      # parses local and global options to determine if a particular mode should
      # be run in parallel. typically, local_options will specify a true/false
      # value, while global_options will specify an array of mode names that should
      # be run in parallel. the value specified in local_options will take precedence
      # over the values specified in global_options.
      # @param [Hash] local_options local options for running in parallel
      # @option local_options [Boolean] :run_in_parallel flag for running in parallel
      # @param [Hash] global_options global options for running in parallel
      # @option global_options [Array<String>] :run_in_parallel list of modes to run in parallel
      # @param [String] mode the mode we want to query global_options for
      # @return [Boolean] true if the specified mode is in global_options and :run_in_parallel in local_options is not false,
      #   or if :run_in_parallel in local_options is true, false otherwise
      # @example
      #   run_in_parallel?({:run_in_parallel => true})
      #   -> will return true
      #
      #   run_in_parallel?({:run_in_parallel => true}, {:run_in_parallel => ['install','configure']}, 'install')
      #   -> will return true
      #
      #   run_in_parallel?({:run_in_parallel => false}, {:run_in_parallel => ['install','configure']}, 'install')
      #   -> will return false
      def run_in_parallel?(local_options=nil, global_options=nil, mode=nil)
        run_in_parallel = local_options[:run_in_parallel] unless local_options.nil?

        if !run_in_parallel.nil? && run_in_parallel.is_a?(Array)
          run_in_parallel = false
        end

        if run_in_parallel.nil? && global_options && global_options[:run_in_parallel].is_a?(Array)
          run_in_parallel = global_options[:run_in_parallel].include?(mode)
        end

        run_in_parallel
      end
    end
  end
end
