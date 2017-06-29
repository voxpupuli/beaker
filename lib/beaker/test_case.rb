[ 'host', 'dsl' ].each do |lib|
  require "beaker/#{lib}"
end

require 'tempfile'
require 'benchmark'
require 'stringio'
require 'rbconfig'

module Beaker
  # This class represents a single test case. A test case is necessarily
  # contained all in one file though may have multiple dependent examples.
  # They are executed in order (save for any teardown procs registered
  # through {Beaker::DSL::Structure#teardown}) and once completed
  # the status of the TestCase is saved. Instance readers/accessors provide
  # the test case access to various details of the environment and suite
  # the test case is running within.
  #
  # See {Beaker::DSL} for more information about writing tests
  # using the DSL.
  class TestCase
    include Beaker::DSL

    # The Exception raised by Ruby's STDLIB's test framework (Ruby 1.9)
    TEST_EXCEPTION_CLASS = ::MiniTest::Assertion

    # Necessary for implementing {Beaker::DSL::Helpers#confine}.
    # Assumed to be an array of valid {Beaker::Host} objects for
    # this test case.
    attr_accessor :hosts

    # Necessary for many methods in {Beaker::DSL}. Assumed to be
    # an instance of {Beaker::Logger}.
    attr_accessor :logger

    # Necessary for many methods in {Beaker::DSL::Helpers}.  Assumed to be
    # a hash.
    attr_accessor :metadata

    # Necessary for {Beaker::DSL::Outcomes}.
    # Assumed to be an Array.
    attr_accessor :exports

    #The full log for this test
    attr_accessor :sublog

    #The result for the last command run
    attr_accessor :last_result

    # A Hash of 'product name' => 'version installed', only set when
    # products are installed via git or PE install steps. See the 'git' or
    # 'pe' directories within 'ROOT/setup' for examples.
    attr_reader :version

    # Parsed command line options.
    attr_reader :options

    # The path to the file which contains this test case.
    attr_reader :path

    # I don't know why this is here
    attr_reader :fail_flag

    # The user that is running this tests home directory, needed by 'net/ssh'.
    attr_reader :usr_home

    # A Symbol denoting the status of this test (:fail, :pending,
    # :skipped, :pass).
    attr_reader :test_status

    # The exception that may have stopped this test's execution.
    attr_reader :exception

    # @deprecated
    # The amount of time taken to execute the test. Unused, probably soon
    # to be removed or refactored.
    attr_reader :runtime

    # An Array of Procs to be called after test execution has stopped
    # (whether by exception or not).
    attr_reader :teardown_procs

    # @deprecated
    # Legacy accessor from when test files would only contain one remote
    # action.  Contains the Result of the last call to utilize
    # {Beaker::DSL::Helpers#on}.  Do not use as it is not safe
    # in test files that use multiple calls to
    # {Beaker::DSL::Helpers#on}.
    attr_accessor :result

    # @param [Hosts,Array<Host>] these_hosts The hosts to execute this test
    #                                        against/on.
    # @param [Logger] logger A logger that implements
    #                        {Beaker::Logger}'s interface.
    # @param [Hash{Symbol=>String}] options Parsed command line options.
    # @param [String] path The local path to a test file to be executed.
    def initialize(these_hosts, logger, options={}, path=nil, last_test=false)
      @hosts   = these_hosts
      @logger = logger
      @sublog = ""
      @options = options
      @path    = path
      @last_test = last_test
      @usr_home = options[:home]
      @test_status = :pass
      @exception = nil
      @runtime = nil
      @teardown_procs = []
      @metadata = {}
      @exports  = []
      set_current_test_filename(@path ? File.basename(@path, '.rb') : nil)


      #
      # We put this on each wrapper (rather than the class) so that methods
      # defined in the tests don't leak out to other tests.
      class << self
        def run_test
          @logger.start_sublog
          @logger.last_result = nil

          set_current_step_name(nil)

          #add arbitrary role methods
          roles = []
          @hosts.each do |host|
            roles << host[:roles]
          end
          add_role_def( roles.flatten.uniq )

          @runtime = Benchmark.realtime do
            begin
              test = File.read(path)
              eval test,nil,path,1
            rescue FailTest, TEST_EXCEPTION_CLASS => e
              log_and_fail_test(e, :fail)
            rescue PendingTest
              @test_status = :pending
            rescue SkipTest
              @test_status = :skip
            rescue StandardError, ScriptError, SignalException => e
              log_and_fail_test(e)
            ensure
              if (@last_test && @options.has_key?(:skip_last_teardown) && @options[:skip_last_teardown] == true)
                @logger.info('Skipping teardown on last test due to skip_last_teardown')
              else
                @logger.info('Begin teardown')
                @teardown_procs.each do |teardown|
                  begin
                    teardown.call
                  rescue StandardError, SignalException, TEST_EXCEPTION_CLASS => e
                    log_and_fail_test(e, :teardown_error)
                  end
                end
                @logger.info('End teardown')
              end
            end
          end
          @sublog = @logger.get_sublog
          @last_result = @logger.last_result
          return self
        end

        private

        # Log an error and mark the test as failed, passing through an
        # exception so it can be displayed at the end of the total run.
        #
        # We break out the complete exception backtrace and log each line
        # individually as well.
        #
        # @param exception [Exception] exception to fail with
        # @param exception [Symbol] the test status
        def log_and_fail_test(exception, status=:error)
          logger.error("#{exception.class}: #{exception.message}")
          bt = exception.backtrace
          logger.pretty_backtrace(bt).each_line do |line|
            logger.error(line)
          end
          # If the status is already a test failure or error, don't overwrite with the teardown failure.
          unless status == :teardown_error && (@test_status == :error || @test_status == :fail)
            status = :error if status == :teardown_error
            @test_status = status
            @exception   = exception
          end
        end
      end
    end

    # The TestCase as a hash
    # @api public
    # @note The visibility and semantics of this method are valid, but the
    #   structure of the Hash it returns may change without notice
    #
    # @return [Hash] A Hash representation of this test.
    def to_hash
      hash = {}
      hash['HOSTS'] = {}
      @hosts.each do |host|
        hash['HOSTS'][host.name] = host.overrides
      end
      hash
    end

  end
end
