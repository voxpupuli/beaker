module Beaker
  module Runner
    module MiniTest
      class TestSuite
        attr_reader :name, :options, :fail_mode # TODO ?

        #Create {TestSuite} instance
        #@param [String] name The name of the {TestSuite}
        #@param [Array<Host>] hosts An Array of Hosts to act upon.
        #@param [Hash{Symbol=>String}] options Options for this object
        #@option options [Logger] :logger The Logger object to report information to
        #@option options [String] :log_dir The directory where text run logs will be written
        #@option options [String] :xml_dir The directory where JUnit XML file will be written
        #@option options [String] :xml_file The name of the JUnit XML file to be written to
        #@option options [String] :project_root The full path to the Beaker lib directory
        #@option options [String] :xml_stylesheet The path to a stylesheet to be applied to the generated XML output
        #@param [Symbol] fail_mode One of :slow, :fast
        #@param [Time] timestamp Beaker execution start time
        def initialize(name, hosts, options, timestamp, fail_mode=nil)
          # TODO ?
        end

        def run
          # TODO ?
        end

        #Execute all the TestCases in this suite.
        #This is a wrapper that catches any failures generated during TestSuite::run.
        def run_and_raise_on_failure
          # TODO ?
        end

        # Gives a full file path for output to be written to, maintaining the latest symlink
        # @param [String] name The file name that we want to write to.
        # @param [String] log_dir The desired output directory.
        #                         A symlink will be made from ./basedir/latest to that.
        # @example
        #   log_path('output.txt', 'log/2014-06-02_16_31_22')
        #
        #     This will create the structure:
        #
        #   ./log/2014-06-02_16_31_22/output.txt
        #   ./log/latest -> 2014-06-02_16_31_22
        #
        # @example
        #   log_path('foo.log', 'log/man/date')
        #
        #     This will create the structure:
        #
        #   ./log/man/date/foo.log
        #   ./log/latest -> man/date
        def log_path(name, log_dir)
          # TODO ?
        end
      end
    end
  end
end
