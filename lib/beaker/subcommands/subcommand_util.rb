require 'rake'
require 'stringio'
require 'yaml/store'
require 'fileutils'

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
    # - execute the quick start task for the specified hypervisor
    # - capture stdout and stderr
    module SubcommandUtil
      BEAKER_REQUIRE = "require 'beaker/tasks/quick_start'"
      HYPERVISORS = ["vagrant", "vmpooler"]
      CONFIG_DIR = ".beaker"
      CONFIG_KEYS = [:hypervisor, :provisioned]
      SUBCOMMAND_OPTIONS = Pathname("#{CONFIG_DIR}/subcommand_options.yaml")
      SUBCOMMAND_STATE = Pathname("#{CONFIG_DIR}/.subcommand_state.yaml")

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

      def self.sanitize_options_for_save(options)
        # God help us, the YAML library won't stop adding tags to objects, so this
        # hack is a way to force the options into the basic object types so that
        # an eventual YAML.dump or .to_yaml call doesn't add tags.
        # Relevant stackoverflow: http://stackoverflow.com/questions/18178098/how-do-i-have-ruby-yaml-dump-a-hash-subclass-as-a-simple-hash
        JSON.parse(options.to_json)
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
        FileUtils.touch(rake_file)
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
        with_captured_output { rake_app.invoke_task(task) }
      end

      # Execute the quick start task for vagrant
      def self.init_vagrant()
        execute_rake_task("beaker_quickstart:gen_hosts[vagrant]")
      end

      # Execute the quick start task for vmpooler
      def self.init_vmpooler()
        execute_rake_task("beaker_quickstart:gen_hosts[vmpooler]")
      end

      # Print a message to the console and exit with specified exit code, defaults to 1
      # @param [String] msg the message to output
      # @param [Hash<Object>] options to specify exit code or output stack trace
      def self.error_with(msg, options={})
        puts msg
        puts options[:stack_trace] if options[:stack_trace]
        exit_code = options[:exit_code] ? options[:exit_code] : 1
        exit(exit_code)
      end

      # Call the quick start task for the specified hypervisor
      # @param [String] hypervisor the hypervisor we want to query
      def self.init_hypervisor(hypervisor)
        case hypervisor
        when "vagrant"
          init_vagrant
        when "vmpooler"
          init_vmpooler
        end
      end

      # Verify that a valid hypervisor has been specified
      # @param [String] hypervisor the hypervisor we want to validate
      def self.verify_init_args(hypervisor)
        unless HYPERVISORS.include?(hypervisor)
          error_with("Invalid hypervisor. Currently supported hypervisors are: #{HYPERVISORS.join(', ')}")
        end
      end

      # Execute a task but capture stdout and stderr to a buffer
      def self.with_captured_output
        begin
          old_stdout = $stdout.clone
          old_stderr = $stderr.clone
          $stdout = StringIO.new
          $stderr = StringIO.new
          yield
        ensure
          $stdout = old_stdout
          $stderr = old_stderr
        end
      end

      # Initialise the beaker config
      def self.init_config()
        FileUtils.mkdir_p CONFIG_DIR
        @@store = YAML::Store.new("#{CONFIG_DIR}/config")
      end

      # Store values from a hash into the beaker config
      # @param [Hash{Symbol=>String}] config values we want to store
      def self.store_config(config)
        @@store.transaction do
          CONFIG_KEYS.each do |key|
            @@store[key] = config[key] unless config[key].nil?
          end
        end
      end

      # Delete keys from the beaker configi
      # @param [Array<Object>] keys the keys we want to delete from the config
      def self.delete_config(keys)
        @@store.transaction {
          keys.each do |key|
            @@store.delete(key)
          end
        }
      end

      # Reset args and provision nodes
      # @param [String] hypervisor the hypervisor to use
      # @param [Array<Object>] options the options to use when provisioning
      def self.provision(hypervisor, options)
        reset_argv(["--hosts", "#{CONFIG_DIR}/acceptance/config/default_#{hypervisor}_hosts.yaml", "--validate", options[:validate], "--configure", options[:configure]])
        beaker = Beaker::CLI.new.parse_options
        beaker.provision
        beaker.preserve_hosts_file
      end
    end
  end
end
