# -*- coding: utf-8 -*-
require 'fileutils'
[ 'test_case', 'logger', 'test_suite_result'].each do |lib|
  require "beaker/#{lib}"
end

module Beaker
  #A collection of {TestCase} objects are considered a {TestSuite}.
  #Handles executing the set of {TestCase} instances and reporting results as post summary text and JUnit XML.
  class TestSuite

    attr_reader :name, :options, :fail_mode

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
      @logger     = options[:logger]
      @test_cases = []
      @test_files = options[name]
      @name       = name.to_s.gsub(/\s+/, '-')
      @hosts      = hosts
      @run        = false
      @options    = options
      @fail_mode  = fail_mode || @options[:fail_mode] || :slow
      @test_suite_results = TestSuiteResult.new(@options, name)
      @timestamp = timestamp

      report_and_raise(@logger, RuntimeError.new("#{@name}: no test files found..."), "TestSuite: initialize") if @test_files.empty?

    rescue => e
      report_and_raise(@logger, e, "TestSuite: initialize")
    end

    #Execute all the {TestCase} instances and then report the results as both plain text and xml.  The text result
    #is reported to a newly created run log.
    #Execution is dependent upon the fail_mode.  If mode is :fast then stop running any additional {TestCase} instances
    #after first failure, if mode is :slow continue execution no matter what {TestCase} results are.
    def run
      @run = true
      start_time = Time.now

      #Create a run log for this TestSuite.
      run_log = log_path("#{@name}-run.log", @options[:log_dated_dir])
      @logger.add_destination(run_log)

      # This is an awful hack to maintain backward compatibility until tests
      # are ported to use logger.  Still in use in PuppetDB tests
      Beaker.const_set(:Log, @logger) unless defined?( Log )

      @test_suite_results.start_time = start_time
      @test_suite_results.total_tests = @test_files.length

      @test_files.each do |test_file|
        @logger.info "Begin #{test_file}"
        start = Time.now
        test_case = TestCase.new(@hosts, @logger, options, test_file).run_test
        duration = Time.now - start
        @test_suite_results.add_test_case(test_case)
        @test_cases << test_case

        state = test_case.test_status == :skip ? 'skipp' : test_case.test_status
        msg = "#{test_file} #{state}ed in %.2f seconds" % duration.to_f
        case test_case.test_status
        when :pass
          @logger.success msg
        when :skip
          @logger.warn msg
        when :fail
          @logger.error msg
          break if @fail_mode.to_s !~ /slow/ #all failure modes except slow cause us to kick out early on failure
        when :error
          @logger.warn msg
          break if @fail_mode.to_s !~ /slow/ #all failure modes except slow cause us to kick out early on failure
        end
      end
      @test_suite_results.stop_time = Time.now

      # REVISIT: This changes global state, breaking logging in any future runs
      # of the suite – or, at least, making them highly confusing for anyone who
      # has not studied the implementation in detail. --daniel 2011-03-14
      @test_suite_results.summarize( Logger.new(log_path("#{name}-summary.txt", @options[:log_dated_dir]), STDOUT) )

      junit_file_log  = log_path(@options[:xml_file], @options[:xml_dated_dir])
      if @options[:xml_time_enabled]
        junit_file_time = log_path(@options[:xml_time], @options[:xml_dated_dir])
        @test_suite_results.write_junit_xml( junit_file_log, @options[:xml_time] )
        @test_suite_results.write_junit_xml( junit_file_time, @options[:xml_file], true )
      else
        @test_suite_results.write_junit_xml( junit_file_log )
      end
      #All done with this run, remove run log
      @logger.remove_destination(run_log)

      # Allow chaining operations...
      return self
    end

    #Execute all the TestCases in this suite.
    #This is a wrapper that catches any failures generated during TestSuite::run.
    def run_and_raise_on_failure
      begin
        run
        return self if @test_suite_results.success?
      rescue => e
        #failed during run
        report_and_raise(@logger, e, "TestSuite :run_and_raise_on_failure")
      else
        #failed during test
        report_and_raise(@logger, RuntimeError.new("Failed while running the #{name} suite"), "TestSuite: report_and_raise_on_failure")
      end
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
      FileUtils.mkdir_p(log_dir) unless File.directory?(log_dir)

      base_dir = log_dir
      link_dir = ''
      while File.dirname(base_dir) != '.' do
        link_dir = link_dir == '' ? File.basename(base_dir) : File.join(File.basename(base_dir), link_dir)
        base_dir = File.dirname(base_dir)
      end

      latest = File.join(base_dir, "latest")
      if !File.exist?(latest) or File.symlink?(latest) then
        File.delete(latest) if File.exist?(latest) || File.symlink?(latest)
        File.symlink(link_dir, latest)
      end

      File.join(log_dir, name)
    end

  end
end
