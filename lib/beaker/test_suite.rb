# -*- coding: utf-8 -*-
require 'nokogiri'
require 'fileutils'
[ 'test_case', 'logger' ].each do |lib|
  require "beaker/#{lib}"
end

module Beaker
  #A collection of {TestCase} objects are considered a {TestSuite}.
  #Handles executing the set of {TestCase} instances and reporting results as post summary text and JUnit XML.
  class TestSuite

    #Holds the output of a test suite, formats in plain text or xml
    class TestSuiteResult
      attr_accessor :start_time, :stop_time, :total_tests

      #Create a {TestSuiteResult} instance.
      #@param [Hash{Symbol=>String}] options Options for this object
      #@option options [Logger] :logger The Logger object to report information to
      #@param [String] name The name of the {TestSuite} that the results are for
      def initialize( options, name )
        @options = options
        @logger = options[:logger]
        @name = name
        @test_cases = []
        #Set some defaults, just in case you attempt to print without including them
        start_time = Time.at(0)
        stop_time = Time.at(1)
      end

      #Add a {TestCase} to this {TestSuiteResult} instance, used in calculating {TestSuiteResult} data.
      #@param [TestCase] test_case An individual, completed {TestCase} to be included in this set of {TestSuiteResult}.
      def add_test_case( test_case )
        @test_cases << test_case
      end

      #How many {TestCase} instances are in this {TestSuiteResult}
      def test_count
        @test_cases.length
      end

      #How many passed {TestCase} instances are in this {TestSuiteResult}
      def passed_tests
        @test_cases.select { |c| c.test_status == :pass }.length
      end

      #How many errored {TestCase} instances are in this {TestSuiteResult}
      def errored_tests
        @test_cases.select { |c| c.test_status == :error }.length
      end

      #How many failed {TestCase} instances are in this {TestSuiteResult}
      def failed_tests
        @test_cases.select { |c| c.test_status == :fail }.length
      end

      #How many skipped {TestCase} instances are in this {TestSuiteResult}
      def skipped_tests
        @test_cases.select { |c| c.test_status == :skip }.length
      end

      #How many pending {TestCase} instances are in this {TestSuiteResult}
      def pending_tests
        @test_cases.select {|c| c.test_status == :pending}.length
      end

      #How many {TestCase} instances failed in this {TestSuiteResult}
      def sum_failed
        failed_tests + errored_tests
      end

      #Did all the {TestCase} instances in this {TestSuiteResult} pass?
      def success?
        sum_failed == 0
      end

      #Did one or more {TestCase} instances in this {TestSuiteResult} fail?
      def failed?
        !success?
      end

      #The sum of all {TestCase} runtimes in this {TestSuiteResult}
      def elapsed_time
        @test_cases.inject(0.0) {|r, t| r + t.runtime.to_f }
      end

      #Plain text summay of test suite
      #@param [Logger] summary_logger The logger we will print the summary to
      def summarize(summary_logger)

        summary_logger.notify <<-HEREDOC
      Test Suite: #{@name} @ #{start_time}

      - Host Configuration Summary -
        HEREDOC

        average_test_time = elapsed_time / test_count

        summary_logger.notify %Q[

              - Test Case Summary for suite '#{@name}' -
       Total Suite Time: %.2f seconds
      Average Test Time: %.2f seconds
              Attempted: #{test_count}
                 Passed: #{passed_tests}
                 Failed: #{failed_tests}
                Errored: #{errored_tests}
                Skipped: #{skipped_tests}
                Pending: #{pending_tests}
                  Total: #{@total_tests}

      - Specific Test Case Status -
        ] % [elapsed_time, average_test_time]

        grouped_summary = @test_cases.group_by{|test_case| test_case.test_status }

        summary_logger.notify "Failed Tests Cases:"
        (grouped_summary[:fail] || []).each do |test_case|
          print_test_result(test_case)
        end

        summary_logger.notify "Errored Tests Cases:"
        (grouped_summary[:error] || []).each do |test_case|
          print_test_result(test_case)
        end

        summary_logger.notify "Skipped Tests Cases:"
        (grouped_summary[:skip] || []).each do |test_case|
          print_test_result(test_case)
        end

        summary_logger.notify "Pending Tests Cases:"
        (grouped_summary[:pending] || []).each do |test_case|
          print_test_result(test_case)
        end

        summary_logger.notify("\n\n")
      end

      #A convenience method for printing the results of a {TestCase}
      #@param [TestCase] test_case The {TestCase} to examine and print results for
      def print_test_result(test_case)
        test_reported = if test_case.exception
                          "reported: #{test_case.exception.inspect}"
                        else
                          test_case.test_status
                        end
        @logger.notify "  Test Case #{test_case.path} #{test_reported}"
      end

      # Writes Junit XML of this {TestSuiteResult}
      #
      # @param [String] xml_file      Path to the XML file (from Beaker's running directory)
      # @param [String] file_to_link  Path to the paired file that should be linked
      #                               from this one (this is relative to the XML
      #                               file itself, so it would just be the different
      #                               file name if they're in the same directory)
      # @param [Boolean] time_sort    Whether the test results should be output in
      #                               order of time spent in the test, or in the
      #                               order of test execution (default)
      #
      # @return nil
      # @api private
      def write_junit_xml(xml_file, file_to_link = nil, time_sort = false)
        stylesheet = File.join(@options[:project_root], @options[:xml_stylesheet])

        begin
          LoggerJunit.write_xml(xml_file, stylesheet) do |doc, suites|

            meta_info = Nokogiri::XML::Node.new('meta_test_info', doc)
            unless file_to_link.nil?
              meta_info['page_active'] = time_sort ? 'performance' : 'execution'
              meta_info['link_url'] = file_to_link
            else
              meta_info['page_active'] = 'no-links'
              meta_info['link_url'] = ''
            end
            suites.add_child(meta_info)

            suite = Nokogiri::XML::Node.new('testsuite', doc)
            suite['name']     = @name
            suite['tests']    = test_count
            suite['errors']   = errored_tests
            suite['failures'] = failed_tests
            suite['skip']     = skipped_tests
            suite['pending']  = pending_tests
            suite['total']    = @total_tests
            suite['time']     = "%f" % (stop_time - start_time)
            properties = Nokogiri::XML::Node.new('properties', doc)
            @options.each_pair do | name, value |
              property = Nokogiri::XML::Node.new('property', doc)
              property['name']  = name
              property['value'] = value
              properties.add_child(property)
            end
            suite.add_child(properties)

            test_cases_to_report = @test_cases
            test_cases_to_report = @test_cases.sort { |x,y| y.runtime <=> x.runtime } if time_sort
            test_cases_to_report.each do |test|
              item = Nokogiri::XML::Node.new('testcase', doc)
              item['classname'] = File.dirname(test.path)
              item['name']      = File.basename(test.path)
              item['time']      = "%f" % test.runtime

              # Did we fail?  If so, report that.
              # We need to remove the escape character from colorized text, the
              # substitution of other entities is handled well by Rexml
              if test.test_status == :fail || test.test_status == :error then
                status = Nokogiri::XML::Node.new('failure', doc)
                status['type'] =  test.test_status.to_s
                if test.exception then
                  status['message'] = test.exception.to_s.gsub(/\e/, '')
                  data = LoggerJunit.format_cdata(test.exception.backtrace.join('\n'))
                  status.add_child(status.document.create_cdata(data))
                end
                item.add_child(status)
              end

              if test.test_status == :skip
                status = Nokogiri::XML::Node.new('skip', doc)
                status['type'] =  test.test_status.to_s
                item.add_child(status)
              end

              if test.test_status == :pending
                status = Nokogiri::XML::Node.new('pending', doc)
                status['type'] =  test.test_status.to_s
                item.add_child(status)
              end

              if test.sublog then
                stdout = Nokogiri::XML::Node.new('system-out', doc)
                data = LoggerJunit.format_cdata(test.sublog)
                stdout.add_child(stdout.document.create_cdata(data))
                item.add_child(stdout)
              end

              if test.last_result and test.last_result.stderr and not test.last_result.stderr.empty? then
                stderr = Nokogiri::XML::Node.new('system-err', doc)
                data = LoggerJunit.format_cdata(test.last_result.stderr)
                stderr.add_child(stderr.document.create_cdata(data))
                item.add_child(stderr)
              end

              suite.add_child(item)
            end
            suites.add_child(suite)
          end
        rescue Exception => e
          @logger.error "failure in XML output:\n#{e.to_s}\n" + e.backtrace.join("\n")
        end

      end
    end

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
