# -*- coding: utf-8 -*-
require 'fileutils'
[ 'test_case', 'logger' , 'test_suite', 'logger_junit'].each do |lib|
  require "beaker/#{lib}"
end

module Beaker
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
        summary_logger.notify print_test_result(test_case)
      end

      summary_logger.notify "Errored Tests Cases:"
      (grouped_summary[:error] || []).each do |test_case|
        summary_logger.notify print_test_result(test_case)
      end

      summary_logger.notify "Skipped Tests Cases:"
      (grouped_summary[:skip] || []).each do |test_case|
        summary_logger.notify print_test_result(test_case)
      end

      summary_logger.notify "Pending Tests Cases:"
      (grouped_summary[:pending] || []).each do |test_case|
        summary_logger.notify print_test_result(test_case)
      end

      summary_logger.notify("\n\n")
    end

    #A convenience method for printing the results of a {TestCase}
    #@param [TestCase] test_case The {TestCase} to examine and print results for
    def print_test_result(test_case)
      if test_case.exception
        test_file_trace = ""
        test_case.exception.backtrace.each do |line|
          if line.include?(test_case.path)
            test_file_trace = "\r\n    Test line: #{line}"
            break
          end
        end if test_case.exception.backtrace && test_case.path
        test_reported = "reported: #{test_case.exception.inspect}#{test_file_trace}"
      else
        test_case.test_status
      end
      "  Test Case #{test_case.path} #{test_reported}"
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

          meta_info = suites.add_element(REXML::Element.new('meta_test_info'))
          unless file_to_link.nil?
            time_sort ? meta_info.add_attribute('page_active', 'performance') : meta_info.add_attribute('page_active', 'execution')
            meta_info.add_attribute('link_url', file_to_link)
          else
            meta_info.add_attribute('page_active', 'no-links')
            meta_info.add_attribute('link_url', '')
          end

          suite = suites.add_element(REXML::Element.new('testsuite'))
          suite.add_attributes(
            [
              ['name' , @name],
              ['tests', test_count],
              ['errors', errored_tests],
              ['failures', failed_tests],
              ['skipped', skipped_tests],
              ['pending', pending_tests],
              ['total', @total_tests],
              ['time', "%f" % (stop_time - start_time)]
          ])
          properties = suite.add_element(REXML::Element.new('properties'))
          @options.each_pair do |name,value|
            property = properties.add_element(REXML::Element.new('property'))
            property.add_attributes([['name', name], ['value', value.to_s || '']])
          end

          test_cases_to_report = @test_cases
          test_cases_to_report = @test_cases.sort { |x,y| y.runtime <=> x.runtime } if time_sort
          test_cases_to_report.each do |test|
            item = suite.add_element(REXML::Element.new('testcase'))
            item.add_attributes(
              [
                ['classname', File.dirname(test.path)],
                ['name', File.basename(test.path)],
                ['time', "%f" % test.runtime]
              ])

            test.exports.each do |export|
              export.keys.each do |key|
                item.add_attribute(key.to_s.tr(" ", "_"), export[key])
              end
            end

            #Report failures
            if test.test_status == :fail || test.test_status == :error
              status = item.add_element(REXML::Element.new('failure'))
              status.add_attribute('type', test.test_status.to_s)
              if test.exception
                status.add_attribute('message', test.exception.to_s.gsub(/\e/,''))
                data = LoggerJunit.format_cdata(test.exception.backtrace.join('\n'))
                REXML::CData.new(data, true, status)
              end
            end

            if test.test_status == :skip
              status = item.add_element(REXML::Element.new('skipped'))
              status.add_attribute('type', test.test_status.to_s)
            end

            if test.test_status == :pending
              status = item.add_element(REXML::Element.new('pending'))
              status.add_attribute('type', test.test_status.to_s)
            end

            if test.sublog
              stdout = item.add_element(REXML::Element.new('system-out'))
              data = LoggerJunit.format_cdata(test.sublog)
              REXML::CData.new(data, true, stdout)
            end

            if test.last_result and test.last_result.stderr and not test.last_result.stderr.empty?
              stderr = item.add_element('system-err')
              data = LoggerJunit.format_cdata(test.last_result.stderr)
              REXML::CData.new(data, true, stderr)
            end
          end
        end
      rescue Exception => e
        @logger.error "failure in XML output: \n#{e.to_s}" + e.backtrace.join("\n")
      end
    end

  end
end
