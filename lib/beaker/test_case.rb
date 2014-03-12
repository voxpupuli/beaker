%w( host answers dsl ).each do |lib|
  begin
    require "beaker/#{lib}"
  rescue LoadError
    require File.expand_path(File.join(File.dirname(__FILE__), lib))
  end
end

require 'tempfile'
require 'benchmark'
require 'stringio'
require 'rbconfig'
#include test/unit, but do not allow it to autorun on exit
require 'test/unit'
if defined?(Test::Unit::AutoRunner.need_auto_run?)
  # For test-unit gem >= 2.4.9
  Test::Unit::AutoRunner.need_auto_run = false
elsif defined?(Test::Unit.run?)
  # For test-unit gem < 2.4.9
  Test::Unit.run = true
elsif defined?(Test::Unit::Runner)
  # For test/unit bundled in Ruby >= 1.9.3
  Test::Unit::Runner.module_eval("@@stop_auto_run = true")
end

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

    rb_config_class = defined?(RbConfig) ? RbConfig : Config
    if rb_config_class::CONFIG['MAJOR'].to_i == 1 &&
      rb_config_class::CONFIG['MINOR'].to_i == 8 then
      # The Exception raised by Ruby's STDLIB's test framework (Ruby 1.8)
      TEST_EXCEPTION_CLASS = Test::Unit::AssertionFailedError
    else
      # The Exception raised by Ruby's STDLIB's test framework (Ruby 1.9)
      TEST_EXCEPTION_CLASS = ::MiniTest::Assertion
    end

    # Necessary for implementing {Beaker::DSL::Helpers#confine}.
    # Assumed to be an array of valid {Beaker::Host} objects for
    # this test case.
    attr_accessor :hosts

    # Necessary for many methods in {Beaker::DSL}. Assumed to be
    # an instance of {Beaker::Logger}.
    attr_accessor :logger

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
    def initialize(these_hosts, logger, options={}, path=nil)
      @hosts   = these_hosts
      @logger = logger
      @options = options
      @path    = path
      @usr_home = options[:home]
      @test_status = :pass
      @exception = nil
      @runtime = nil
      @teardown_procs = []


      #
      # We put this on each wrapper (rather than the class) so that methods
      # defined in the tests don't leak out to other tests.
      class << self
        def run_test
          @runtime = Benchmark.realtime do
            begin
              test = File.read(path)
              eval test,nil,path,1
            rescue FailTest, TEST_EXCEPTION_CLASS => e
              @test_status = :fail
              @exception   = e
            rescue PendingTest
              @test_status = :pending
            rescue SkipTest
              @test_status = :skip
            rescue StandardError, ScriptError, SignalException => e
              log_and_fail_test(e)
            ensure
              @teardown_procs.each do |teardown|
                begin
                  teardown.call
                rescue StandardError, SignalException => e
                  log_and_fail_test(e)
                end
              end
            end
          end
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
        def log_and_fail_test(exception)
          logger.error(exception.inspect)
          bt = exception.backtrace
          logger.pretty_backtrace(bt).each_line do |line|
            logger.error(line)
          end
          @test_status = :error
          @exception   = exception
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
