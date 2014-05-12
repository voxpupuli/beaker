require 'open-uri'
module Beaker
  module Options
    #A set of functions to read options files
    module OptionsFileParser

      # Eval the contents of options_file_path, return as an OptionsHash
      #
      # Options file is assumed to contain extra options stored in a Hash
      #
      # ie,
      #   {
      #     :debug => true,
      #     :tests => "test.rb",
      #   }
      #
      # @param [String] options_file_path The path to the options file
      #
      # @example
      #     options_hash = OptionsFileParser.parse_options_file('sample.cfg')
      #     options_hash == {:debug=>true, :tests=>"test.rb", :pre_suite=>["pre-suite.rb"], :post_suite=>"post_suite1.rb,post_suite2.rb"}
      #
      # @return [OptionsHash] The contents of the options file as an OptionsHash
      # @raise [ArgumentError] Raises if options_file_path is not a path to a file
      # @note Since the options_file is Eval'ed, any other Ruby commands will also be executed, this can be used
      #    to set additional environment variables
      def self.parse_options_file(options_file_path)
        result = Beaker::Options::OptionsHash.new
        if options_file_path
          options_file_path = File.expand_path(options_file_path)
          unless File.exists?(options_file_path)
            raise ArgumentError, "Specified options file '#{options_file_path}' does not exist!"
          end
          # This eval will allow the specified options file to have access to our
          #  scope.  It is important that the variable 'options_file_path' is
          #  accessible, because some existing options files (e.g. puppetdb) rely on
          #  that variable to determine their own location (for use in 'require's, etc.)
          result = result.merge(eval(File.read(options_file_path)))
        end
        result
      end

    end
  end
end
