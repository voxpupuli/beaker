require 'rake'

module Beaker
  module Subcommands
    # Methods used in execution of Subcommands
    # - should we execute a subcommand?
    # - reset ARGV
    # - execute Beaker
    # - update a rakefile to require beaker quickstart tasks
    # - initialise a rake application
    # - execute a rake task
    # - execute the vagrant quickstart task
    # - execute the vmpooler quickstart task
    # - exit with a specific message
    # - verify that the init subcommand has the correct arguments
    # - execute the quick start task for the specified hypervisor
    module SubcommandUtil
      BEAKER_REQUIRE = "require 'beaker/tasks/quick_start'"
      HYPERVISORS = ["vagrant", "vmpooler"]

      # Check if the first argument to the beaker execution is a subcommand
      # @return [Boolean] true if argv[0] is "help" or a method defined in the Subcommands class, false otherwise
      def self.execute_subcommand?(arg0)
        return false if arg0.nil?
        (Beaker::Subcommand.instance_methods(false) << :help).include? arg0.to_sym
      end

      # Reset ARGV to contain the arguments determined by a specific subcommand
      # @param [Array<String>] args the arguments determined by a specific subcommand
      def self.reset_argv(args)
        ARGV.clear
        args.each do |arg|
          ARGV << arg
        end
      end

      # Update ARGV and call Beaker
      # @param [Array<String>] args the arguments determined by a specific subcommand
      def self.execute_beaker(*args)
        reset_argv(args)
        Beaker::CLI.new.execute!
      end

      # Determines what Rakefile to use
      # @return [String] the name of the rakefile to use
      def self.determine_rake_file()
        rake_app.find_rakefile_location() ? rake_app.find_rakefile_location()[0] : "Rakefile"
      end

      # Check for the presence of a Rakefile containing the require of the
      # quick start tasks
      def self.require_tasks()
        rake_file = determine_rake_file()
        unless File.readlines(rake_file).grep(/#{BEAKER_REQUIRE}/).any?
          File.open(rake_file, "a+") { |f| f.puts(BEAKER_REQUIRE) }
        end
      end

      # Initialises a rake application
      # @return [Object] a rake application
      def self.rake_app()
        unless @rake_app
          ARGV.clear
          @rake_app = Rake.application
          @rake_app.init
        end
        @rake_app
      end

      # Clear ARGV and execute a Rake task
      # @param [String] task the rake task to execute
      def self.execute_rake_task(task)
        rake_app.load_rakefile()
        rake_app.invoke_task(task)
      end

      # Execute the quick start task for vagrant
      def self.init_vagrant()
        execute_rake_task("beaker_quickstart:gen_hosts[vagrant]")
      end

      # Execute the quick start task for vmpooler
      def self.init_vmpooler()
        execute_rake_task("beaker_quickstart:gen_hosts[vmpooler]")
      end

      # Print a message to the console and exit with 0
      # @param [String] msg the message to print
      def self.exit_with(msg)
        puts msg
        exit(0)
      end

      # Verify that a valid hypervisor has been specified
      # @param [Array<Object>] options the options we want to query
      def self.verify_init_args(options)
        unless HYPERVISORS.include?(options[:hypervisor])
          exit_with("Invalid hypervisor. Currently supported hypervisors are: #{HYPERVISORS.join(', ')}")
        end
      end

      # Call the quick start task for the specified hypervisor
      # @param [Array<Object>] options the options we want to query
      def self.init_hypervisor(options)
        case options[:hypervisor]
        when "vagrant"
          init_vagrant
        when "vmpooler"
          init_vmpooler
        end
      end
    end
  end
end
