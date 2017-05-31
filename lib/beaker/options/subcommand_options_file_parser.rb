module Beaker
  module Options
    #A set of functions to read options files
    module SubcommandOptionsParser

      HOMEDIR_OPTIONS_FILE_PATH = ENV['HOME']+'/.beaker/subcommand_options.yaml'

      def self.parse_options_file(options_file_path)
        result = OptionsHash.new
        if File.exist?(options_file_path)
          result = YAML.load_file(options_file_path)
        end
        result
      end

      # @return [OptionsHash, Hash] returns an empty OptionHash or loads subcommand options yaml
      #   from disk
      def self.parse_subcommand_options(argv, home_dir=false)
        result = OptionsHash.new
        if Beaker::Subcommands::SubcommandUtil.execute_subcommand?(argv[0])
          return result if argv[0] == 'init'
          if home_dir
            return SubcommandOptionsParser.parse_options_file(HOMEDIR_OPTIONS_FILE_PATH)
          end
          result = SubcommandOptionsParser.parse_options_file(Beaker::Subcommands::SubcommandUtil::SUBCOMMAND_OPTIONS)
        end
        result
      end

    end
  end
end
