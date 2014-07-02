require 'rake/task_arguments'
require 'rake/tasklib'
require 'rake'
require 'beaker'


module Beaker
  module Tasks
    class RakeTask < ::Rake::TaskLib
      include ::Rake::DSL if defined?(::Rake::DSL)

      DEFAULT_ACCEPTANCE_ROOT = "./acceptance"

      COMMAND_OPTIONS = [:fail_mode,
       :hosts,
       :helper,
       :keyfile,
       :log_level,
       :options_file,
       :preserve_hosts,
       :tests,
       :type,
       :acceptance_root,
       :name]
      # iterates of acceptable params
      COMMAND_OPTIONS.each do |sym|
        attr_accessor(sym.to_sym)
      end

      # Sets up the predefine task checking
      # @param args [Array] First argument is always the name of the task
      # if no additonal arguments are defined such as parameters it will default to [:hosts,:type]
      def initialize(*args, &task_block)
        @name = args.shift || 'beaker:test'
        if args.empty?
          args = [:hosts,:type]
        end
        @acceptance_root = DEFAULT_ACCEPTANCE_ROOT
        @options_file = nil
        define(args, &task_block)
      end

      private
      # Run the task provided, implements the rake task interface
      #
      # @param verbose [bool] Defines wether to run in verbose mode or not
      def run_task(verbose)
        puts "Running task"

        check_for_beaker_type_config
        command = beaker_command
        puts command if verbose
        success = system(command)
        if fail_mode == "fast" && !success
          $stderr.puts "#{command} failed"
          exit $?.exitstatus
        end
      end

      # @private
      def define(args, &task_block)
        desc "Run Beaker Acceptance" unless ::Rake.application.last_comment
        task name, *args do |_, task_args|
          RakeFileUtils.__send__(:verbose, verbose) do
            task_block.call(*[self, task_args].slice(0, task_block.arity)) if task_block
            run_task verbose
          end
        end
      end

      #
      # If an options file exists in the acceptance path for the type given use it as a default options file
      #   if no other options file is provided
      #
      def check_for_beaker_type_config
        if !@options_file && File.exists?("#{@acceptance_root}/.beaker-#{@type}.cfg")
          @options_file = File.join(@acceptance_root, ".beaker-#{@type}.cfg")
        end
      end

      #
      # Check for existence of ENV variables for test if !@tests is undef
      #
      def check_env_variables
        if File.exists?(File.join(DEFAULT_ACCEPTANCE_ROOT, 'tests'))
          @tests = File.join(DEFAULT_ACCEPTANCE_ROOT, 'tests')
        end
        @tests = ENV['TESTS'] || ENV['TEST'] if !@tests
      end

      #
      # Generate the beaker command to run beaker with all possible options passed
      #
      def beaker_command
        cmd_parts = []
        cmd_parts << "beaker"
        cmd_parts << "--keyfile #{@keyfile}" if @keyfile
        cmd_parts << "--hosts #{@hosts}" if @hosts
        cmd_parts << "--tests #{tests}" if @tests
        cmd_parts << "--options-file #{@options_file}" if @options_file
        cmd_parts << "--type #{@type}" if @type
        cmd_parts << "--helper #{@helper}" if @helper
        cmd_parts << "--fail-mode #{@fail_mode}" if @fail_mode
        cmd_parts.flatten.join(" ")
      end
    end
  end
end
