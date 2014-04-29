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

      COMMAND_OPTIONS.each do |sym|
        attr_accessor(sym.to_sym)
      end

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
      def run_task(verbose)
        puts "Running task"

        check_for_beaker_type_config
        command = beaker_command

        begin
          puts command if verbose
          success = system(command)
        rescue
          puts failure_message if failure_message
        end
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

      def check_for_beaker_type_config
        if !@options_file && File.exists?("#{@acceptance_root}/.beaker-#{@type}.cfg")
          @options_file = File.join(@acceptance_root, ".beaker-#{@type}.cfg")
        end
      end

      def check_env_variables
        if File.exists?(File.join(DEFAULT_ACCEPTANCE_ROOT, 'tests'))
          @tests = File.join(DEFAULT_ACCEPTANCE_ROOT, 'tests')
        end
        @tests = ENV['TESTS'] || ENV['TEST'] if !@tests
      end

      def merge_options(args)
        options_parser = Beaker::Options::CommandLineParser.new
        options = options_parser.parse!(args)
        puts options
      end

      def beaker_command
        @b_command ||= begin
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
end
Beaker::Tasks::RakeTask.new
desc "Run Beaker PE tests"
Beaker::Tasks::RakeTask.new("beaker:test:pe",:hosts) do |t,args|
  t.type = 'pe'
end

desc "Run Beaker Git tests"
Beaker::Tasks::RakeTask.new("beaker:test:git",:hosts) do |t,args|
  t.type = 'git'
end