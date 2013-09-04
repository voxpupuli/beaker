require 'open-uri'
module Beaker
  module Options
    module OptionsFileParser

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
