module Beaker
  module Shared
    # Methods used in execution of Subcommands
    # - should we write the config?
    # - reset ARGV 
    # - execute Beaker
    module SubcommandsUtil
      CONFIG_PATH = ".beaker/config"
    
      @@write_config = false

      def self.write_config=( val )
        @@write_config = val
      end
      
      def self.write_config?
        @@write_config
      end
      
      # Reset ARGV to contain the arguments determined by a specific subcommand
      # @param [Array<String>] args the arguments determined by a specific subcommand
      def reset_argv(args)
        ARGV.clear
        args.each do |arg|
          ARGV << arg
        end
      end

      # Update ARGV and call Beaker
      # @param [Array<String>] args the arguments determined by a specific subcommand
      def execute_beaker(*args)
        reset_argv(args)
        Beaker::CLI.new.execute! 
      end
    end
  end
end
