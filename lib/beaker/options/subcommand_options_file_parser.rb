module Beaker
  module Options
    #A set of functions to read options files
    module SubcommandOptionsParser

      # @return [OptionsHash, Hash] returns an empty OptionHash or loads subcommand options yaml
      #   from disk
      def self.parse_subcommand_options(argv)
        result = OptionsHash.new
        if Beaker::Subcommands::SubcommandUtil.execute_subcommand?(argv[0])
          return result if argv[0] == 'init'
          if Beaker::Subcommands::SubcommandUtil::SUBCOMMAND_OPTIONS.exist?
           result = YAML.load_file(Beaker::Subcommands::SubcommandUtil::SUBCOMMAND_OPTIONS)
          end
        end
        result
      end
    end
  end
end
