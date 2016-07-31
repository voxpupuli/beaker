module Beaker
  module Shared
    # Methods for parsing options.
    # - determine if a mode should be run in parallel
    module OptionsResolver
      def run_in_parallel?(opts, options, mode)
        run_in_parallel = opts[:run_in_parallel] unless opts.nil?

        if !run_in_parallel.nil? && run_in_parallel.is_a?(Array)
          run_in_parallel = false
        end

        if run_in_parallel.nil? && options && options[:run_in_parallel].is_a?(Array)
          run_in_parallel = options[:run_in_parallel].include?(mode)
        end

        run_in_parallel
      end
    end
  end
end
