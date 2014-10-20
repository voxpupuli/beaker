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

      #Remove color codes from provided string.  Color codes are of the format /(\e\[\d\d;\d\dm)+/. 
      #@param [String] text The string to remove color codes from
      #@return [String] The text without color codes
      def strip_color_codes(text)
        text.gsub(/(\e|\^\[)\[(\d*;)*\d*m/, '')
      end

      # Determine if the provided number falls in the range of accepted xml unicode values
      # See http://www.w3.org/TR/xml/#charsets for valid for valid character specifications.
      # @param [Integer] int The number to check against
      # @return [Boolean] True, if the number corresponds to a valid xml unicode character, otherwise false
      def is_valid_xml(int)
        return ( int == 0x9 or
                 int == 0xA or
               ( int >= 0x0020 and int <= 0xD7FF ) or
               ( int >= 0xE000 and int <= 0xFFFD ) or
               ( int >= 0x100000 and int <= 0x10FFFF )
        )
      end

      # Escape invalid XML UTF-8 codes from provided string, see http://www.w3.org/TR/xml/#charsets for valid
      # character specification
      # @param [String] string The string to remove invalid codes from
      def escape_invalid_xml_chars string
        escaped_string = ""
        string.chars.each do |i|
          char_as_codestring = i.unpack("U*").join
          if is_valid_xml(char_as_codestring.to_i)
            escaped_string << i
          else
            escaped_string << "\\#{char_as_codestring}"
          end
        end
        escaped_string
      end

      # Remove color codes and invalid XML characters from provided string
      # @param [String] string The string to format
      def format_cdata string
        escape_invalid_xml_chars(strip_color_codes(string))
      end

      #Format and print the {TestSuiteResult} as JUnit XML
      #@param [String] xml_file The full path to print the output to.
      #@param [String] stylesheet The full path to a JUnit XML stylesheet
      def write_junit_xml(xml_file, stylesheet)
        begin

          #copy stylesheet into xml directory
          if not File.file?(File.join(File.dirname(xml_file), File.basename(stylesheet)))
            FileUtils.copy(stylesheet, File.join(File.dirname(xml_file), File.basename(stylesheet)))
          end
          suites = nil
          #check to see if an output file already exists, if it does add or replace test suite data
          if File.file?(xml_file)
            doc = Nokogiri::XML( File.open(xml_file, 'r') )
            suites = doc.at_xpath('testsuites')
            #remove old data
            doc.search("//testsuite").each do |node|
              if node['name'] =~ /#{@name}/
                node.unlink
              end
            end
          else
            #no existing file, create a new one
            doc = Nokogiri::XML::Document.new()
            doc.encoding = 'UTF-8'
            pi = Nokogiri::XML::ProcessingInstruction.new(doc, "xml-stylesheet", "type=\"text/xsl\" href=\"#{File.basename(stylesheet)}\"")
            pi.parent = doc
            suites = Nokogiri::XML::Node.new('testsuites', doc)
            suites.parent = doc
          end

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

          @test_cases.each do |test|
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
                data = format_cdata(test.exception.backtrace.join('\n'))
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
              data = format_cdata(test.sublog)
              stdout.add_child(stdout.document.create_cdata(data))
              item.add_child(stdout)
            end

            if test.last_result and test.last_result.stderr and not test.last_result.stderr.empty? then
              stderr = Nokogiri::XML::Node.new('system-err', doc)
              data = format_cdata(test.last_result.stderr)
              stderr.add_child(stderr.document.create_cdata(data))
              item.add_child(stderr)
            end

            suite.add_child(item)
          end
          suites.add_child(suite)

          # junit/name.xml will be created in a directory relative to the CWD
          # --  JLS 2/12
          File.open(xml_file, 'w') { |fh| fh.write(doc.to_xml) }

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
    def initialize(name, hosts, options, timestamp, fail_mode = :slow)
      @logger     = options[:logger]
      @test_cases = []
      @test_files = options[name]
      @name       = name.to_s.gsub(/\s+/, '-')
      @hosts      = hosts
      @run        = false
      @options    = options
      @fail_mode  = fail_mode || @options[:fail_mode]
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
      run_log = log_path(@timestamp, "#{@name}-run.log", @options[:log_dir])
      @logger.add_destination(run_log)

      # This is an awful hack to maintain backward compatibility until tests
      # are ported to use logger.  Still in use in PuppetDB tests
      Beaker.const_set(:Log, @logger) unless defined?( Log )

      @test_suite_results.start_time = start_time
      @test_suite_results.total_tests = @test_files.length

      @test_files.each do |test_file|
        @logger.notify "Begin #{test_file}"
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
          @logger.debug msg
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
      @test_suite_results.summarize( Logger.new(log_path(@timestamp, "#{name}-summary.txt", @options[:log_dir]), STDOUT) )
      @test_suite_results.write_junit_xml( log_path(@timestamp, @options[:xml_file], @options[:xml_dir]), File.join(@options[:project_root], @options[:xml_stylesheet]) )

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

    #Create a full file path for output to be written to, using the provided timestamp, name and output directory.
    #@param [Time] timestamp The time that we are making this path with
    #@param [String] name The file name that we want to write to.
    #@param [String] basedir The desired output directory.  A subdirectory tagged with the time will be created which will contain
    #                        the output file (./basedir/timestamp/).  
    #                        A symlink will be made from that to ./basedir/timestamp/latest.
    #@example
    #  log_path('2014-06-02 16:31:22 -0700','output.txt', 'log')
    #
    #    This will create the structure:
    #
    #  ./log/2014-06-02_16_31_22/output.txt
    #  ./log/latest -> 2014-06-02_16_31_22
    def log_path(timestamp, name, basedir)
      log_dir = File.join(basedir, timestamp.strftime("%F_%H_%M_%S"))
      unless File.directory?(log_dir) then
        FileUtils.mkdir_p(log_dir)

        latest = File.join(basedir, "latest")
        if !File.exist?(latest) or File.symlink?(latest) then
          File.delete(latest) if File.exist?(latest)
          File.symlink(File.basename(log_dir), latest)
        end
      end

      File.join(basedir, 'latest', name)
    end

  end
end
