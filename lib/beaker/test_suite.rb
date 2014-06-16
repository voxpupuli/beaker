# -*- coding: utf-8 -*-
require 'rexml/document'
require 'fileutils'
[ 'test_case', 'logger' ].each do |lib|
  require "beaker/#{lib}"
end

module Beaker
  # This Class is in need of some cleaning up beyond what can be quickly done.
  # Things to keep in mind:
  #   * Global State Change
  #   * File Creation Relative to CWD  -- Should be a config option
  #   * Better Method Documentation
  class TestSuite
    attr_reader :name, :options, :fail_mode

    def initialize(name, hosts, options, fail_mode = nil)
      @logger     = options[:logger]
      @test_cases = []
      @test_files = options[name]
      @name       = name.to_s.gsub(/\s+/, '-')
      @hosts      = hosts
      @run        = false
      @options    = options
      @fail_mode  = options[:fail_mode] || fail_mode

      report_and_raise(@logger, RuntimeError.new("#{@name}: no test files found..."), "TestSuite: initialize") if @test_files.empty?

    rescue => e
      report_and_raise(@logger, e, "TestSuite: initialize")
    end

    def run
      @run = true
      @start_time = Time.now

      configure_logging

      @test_files.each do |test_file|
        @logger.notify "Begin #{test_file}"
        start = Time.now
        test_case = TestCase.new(@hosts, @logger, options, test_file).run_test
        duration = Time.now - start
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
          break if fail_mode !~ /slow/ #all failure modes except slow cause us to kick out early on failure
        when :error
          @logger.warn msg
          break if fail_mode !~ /slow/ #all failure modes except slow cause us to kick out early on failure
        end
      end

      # REVISIT: This changes global state, breaking logging in any future runs
      # of the suite – or, at least, making them highly confusing for anyone who
      # has not studied the implementation in detail. --daniel 2011-03-14
      summarize
      write_junit_xml if options[:xml]

      # Allow chaining operations...
      return self
    end

    def run_and_raise_on_failure
      begin
        run
        return self if success?
      rescue => e
        #failed during run
        report_and_raise(@logger, e, "TestSuite :run_and_raise_on_failure")
      else
        #failed during test
        report_and_raise(@logger, RuntimeError.new("Failed while running the #{name} suite"), "TestSuite: report_and_raise_on_failure")
      end
    end

    def fail_without_test_run
      report_and_raise(@logger, RuntimeError.new("#{@name}: you have not run the tests yet"), "TestSuite: fail_without_test_run") unless @run
    end

    def success?
      fail_without_test_run
      sum_failed == 0
    end

    def failed?
      !success?
    end

    def test_count
      @test_count ||= @test_cases.length
    end

    def passed_tests
      @passed_tests ||= @test_cases.select { |c| c.test_status == :pass }.length
    end

    def errored_tests
      @errored_tests ||= @test_cases.select { |c| c.test_status == :error }.length
    end

    def failed_tests
      @failed_tests ||= @test_cases.select { |c| c.test_status == :fail }.length
    end

    def skipped_tests
      @skipped_tests ||= @test_cases.select { |c| c.test_status == :skip }.length
    end

    def pending_tests
      @pending_tests ||= @test_cases.select {|c| c.test_status == :pending}.length
    end

    private

    def sum_failed
      @sum_failed ||= failed_tests + errored_tests
    end

    def write_junit_xml
      # This should be a configuration option
      File.directory?('junit') or FileUtils.mkdir('junit')

      begin
        doc   = REXML::Document.new
        doc.add(REXML::XMLDecl.new(1.0))

        suite = REXML::Element.new('testsuite', doc)
        suite.add_attribute('name',     name)
        suite.add_attribute('tests',    test_count)
        suite.add_attribute('errors',   errored_tests)
        suite.add_attribute('failures', failed_tests)
        suite.add_attribute('skip',     skipped_tests)
        suite.add_attribute('pending',  pending_tests)

        @test_cases.each do |test|
          item = REXML::Element.new('testcase', suite)
          item.add_attribute('classname', File.dirname(test.path))
          item.add_attribute('name',      File.basename(test.path))
          item.add_attribute('time',      test.runtime)

          # Did we fail?  If so, report that.
          # We need to remove the escape character from colorized text, the
          # substitution of other entities is handled well by Rexml
          if test.test_status == :fail || test.test_status == :error then
            status = REXML::Element.new('failure', item)
            status.add_attribute('type', test.test_status.to_s)
            if test.exception then
              status.add_attribute('message', test.exception.to_s.gsub(/\e/, ''))
              status.text = test.exception.backtrace.join("\n")
            end
          end

          if test.stdout then
            REXML::Element.new('system-out', item).text =
              test.stdout.gsub(/\e/, '')
          end

          if test.stderr then
            text = REXML::Element.new('system-err', item)
            text.text = test.stderr.gsub(/\e/, '')
          end
        end

        # junit/name.xml will be created in a directory relative to the CWD
        # --  JLS 2/12
        File.open("junit/#{name}.xml", 'w') { |fh| doc.write(fh) }
      rescue Exception => e
        @logger.error "failure in XML output:\n#{e.to_s}\n" + e.backtrace.join("\n")
      end
    end

    def summarize
      fail_without_test_run

      summary_logger = Logger.new(log_path("#{name}-summary.txt"), STDOUT)

      summary_logger.notify <<-HEREDOC
    Test Suite: #{name} @ #{@start_time}

    - Host Configuration Summary -
      HEREDOC

      elapsed_time = @test_cases.inject(0.0) {|r, t| r + t.runtime.to_f }
      average_test_time = elapsed_time / test_count

      summary_logger.notify %Q[

            - Test Case Summary for suite '#{name}' -
     Total Suite Time: %.2f seconds
    Average Test Time: %.2f seconds
            Attempted: #{test_count}
               Passed: #{passed_tests}
               Failed: #{failed_tests}
              Errored: #{errored_tests}
              Skipped: #{skipped_tests}
              Pending: #{pending_tests}

    - Specific Test Case Status -
      ] % [elapsed_time, average_test_time]

      grouped_summary = @test_cases.group_by{|test_case| test_case.test_status }

      summary_logger.notify "Failed Tests Cases:"
      (grouped_summary[:fail] || []).each do |test_case|
        print_test_failure(test_case)
      end

      summary_logger.notify "Errored Tests Cases:"
      (grouped_summary[:error] || []).each do |test_case|
        print_test_failure(test_case)
      end

      summary_logger.notify "Skipped Tests Cases:"
      (grouped_summary[:skip] || []).each do |test_case|
        print_test_failure(test_case)
      end

      summary_logger.notify "Pending Tests Cases:"
      (grouped_summary[:pending] || []).each do |test_case|
        print_test_failure(test_case)
      end

      summary_logger.notify("\n\n")
    end

    def print_test_failure(test_case)
      test_reported = if test_case.exception
                        "reported: #{test_case.exception.inspect}"
                      else
                        test_case.test_status
                      end
      @logger.notify "  Test Case #{test_case.path} #{test_reported}"
    end

    def log_path(name)
      @@log_dir ||= File.join("log", @start_time.strftime("%F_%H_%M_%S"))
      unless File.directory?(@@log_dir) then
        FileUtils.mkdir_p(@@log_dir)

        latest = File.join("log", "latest")
        if !File.exist?(latest) or File.symlink?(latest) then
          File.delete(latest) if File.exist?(latest)
          File.symlink(File.basename(@@log_dir), latest)
        end
      end

      File.join('log', 'latest', name)
    end

    # Setup log dir
    def configure_logging
      @logger.add_destination(log_path("#{@name}-run.log"))
      #
      # This is an awful hack to maintain backward compatibility until tests
      # are ported to use logger.
      Beaker.const_set(:Log, @logger) unless defined?( Log )
    end
  end
end
