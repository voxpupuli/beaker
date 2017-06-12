module Beaker
  module Options
    #A set of functions to read options files
    module SubcommandOptionsParser

      def self.parse_options_file(options_file_path)
        result = OptionsHash.new
        if File.exist?(options_file_path)
          result = YAML.load_file(options_file_path)
        end
        result
      end

      # @return [OptionsHash, Hash] returns an empty OptionHash or loads subcommand options yaml
      #   from disk
      def self.parse_subcommand_options(argv, options_file)
        result = OptionsHash.new
        if Beaker::Subcommands::SubcommandUtil.execute_subcommand?(argv[0])
          return result if argv[0] == 'init'
          result = SubcommandOptionsParser.parse_options_file(options_file)
        end
        result
      end

    end
  end
end
