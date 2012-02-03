# -*- coding: utf-8 -*-
require 'rexml/document'

class TestSuite
  attr_reader :name, :options, :config, :stop_on_error

  def initialize(name, hosts, options, config, stop_on_error=FALSE)
    @name    = name.gsub(/\s+/, '-')
    @hosts   = hosts
    @run     = false
    @options = options
    @config  = config
    @stop_on_error = stop_on_error

    @test_cases = []
    @test_files = []

    Array(options[:tests] || 'tests').each do |root|
      if File.file? root then
        @test_files << root
      else
        @test_files += Dir[File.join(root, "**/*.rb")].select { |f| File.file?(f) }
      end
    end
    fail "no test files found..." if @test_files.empty?

    if options[:random]
      @random_seed = (options[:random] == true ? Time.now : options[:random]).to_i
      srand @random_seed
      @test_files = @test_files.sort_by { rand }
    else
      @test_files = @test_files.sort
    end
  end

  def run
    @run = true
    @start_time = Time.now

    initialize_logfiles

    Log.notify "Using random seed #{@random_seed}" if @random_seed
    @test_files.each do |test_file|
      Log.notify
      Log.notify "Begin #{test_file}"
      start = Time.now
      test_case = TestCase.new(@hosts, config, options, test_file).run_test
      duration = Time.now - start
      @test_cases << test_case

      msg = "#{test_file} #{test_case.test_status == :skip ? 'skipp' : test_case.test_status}ed in %.2f seconds" % duration.to_f
      case test_case.test_status
      when :pass
        Log.success msg
      when :skip
        Log.debug msg
      when :fail
        Log.error msg
        break if stop_on_error
      when :error
        Log.warn msg
        break if stop_on_error
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

  def run_and_exit_on_failure
    run
    return self if success?
    Log.error "Failed while running the #{name} suite..."
    exit 1
  end

  def success?
    fail "you have not run the tests yet" unless @run
    sum_failed == 0
  end
  def failed?
    !success?
  end

  def test_count
    fail "you have not run the tests yet" unless @run
    @test_cases.length
  end

  def test_errors
    fail "you have not run the tests yet" unless @run
    @test_cases.select { |c| c.test_status == :error } .length
  end

  def test_failures
    fail "you have not run the tests yet" unless @run
    @test_cases.select { |c| c.test_status == :fail } .length
  end

  def test_skips
    fail "you have not run the tests yet" unless @run
    @test_cases.select { |c| c.test_status == :skip} .length
  end

  private

  def sum_failed
    test_failed=0
    test_passed=0
    test_errored=0
    test_skips=0
    @test_cases.each do |test_case|
      case test_case.test_status
      when :pass  then test_passed  += 1
      when :fail  then test_failed  += 1
      when :error then test_errored += 1
      when :skip  then test_skips   += 1
      end
    end
    test_failed + test_errored
  end

  def write_junit_xml
    File.directory?('junit') or FileUtils.mkdir('junit')

    begin
      doc   = REXML::Document.new
      doc.add(REXML::XMLDecl.new(1.0))

      suite = REXML::Element.new('testsuite', doc)
      suite.add_attribute('name',     name)
      suite.add_attribute('tests',    test_count)
      suite.add_attribute('errors',   test_errors)
      suite.add_attribute('failures', test_failures)
      suite.add_attribute('skip',     test_skips)

      @test_cases.each do |test|
        item = REXML::Element.new('testcase', suite)
        item.add_attribute('classname', File.dirname(test.path))
        item.add_attribute('name',      File.basename(test.path))
        item.add_attribute('time',      test.runtime)

        # Did we fail?  If so, report that.
        unless test.test_status == :pass || test.test_status == :skip then
          status = REXML::Element.new('failure', item)
          status.add_attribute('type', test.test_status.to_s)
          if test.exception then
            status.add_attribute('message', test.exception.to_s)
            status.text = test.exception.backtrace.join("\n")
          end
        end

        if test.stdout then
          REXML::Element.new('system-out', item).text =
            test.stdout.gsub(/[\0-\011\013\014\016-\037]/) {|c| "&#{c[0]};" }
        end

        if test.stderr then
          text = REXML::Element.new('system-err', item)
          text.text = test.stderr.gsub(/[\0-\011\013\014\016-\037]/) {|c| "&#{c[0]};" }
        end
      end

      File.open("junit/#{name}.xml", 'w') { |fh| doc.write(fh) }
    rescue Exception => e
      Log.error "failure in XML output:\n#{e.to_s}\n" + e.backtrace.join("\n")
    end
  end

  def summarize
    fail "you have not run the tests yet" unless @run

    if Log.file then
      Log.file = log_path("#{name}-summary.txt")
    end
    Log.stdout = true

    Log.notify <<-HEREDOC
  Test Suite: #{name} @ #{@start_time}

  - Host Configuration Summary -
    HEREDOC

    TestConfig.dump(config)

    test_failed=0
    test_passed=0
    test_errored=0
    test_skips=0
    @test_cases.each do |test_case|
      case test_case.test_status
      when :pass  then test_passed  += 1
      when :fail  then test_failed  += 1
      when :error then test_errored += 1
      when :skip  then test_skips   += 1
      end
    end
    grouped_summary = @test_cases.group_by{|test_case| test_case.test_status }

    Log.notify <<-HEREDOC

  - Test Case Summary -
  Attempted: #{@test_cases.length}
     Passed: #{test_passed}
     Failed: #{test_failed}
    Errored: #{test_errored}
    Skipped: #{test_skips}

  - Specific Test Case Status -
  HEREDOC

    Log.notify "Failed Tests Cases:"
    (grouped_summary[:fail] || []).each {|test_case| print_test_failure(test_case)}

    Log.notify "Errored Tests Cases:"
    (grouped_summary[:error] || []).each {|test_case| print_test_failure(test_case)}

    Log.notify "Skipped Tests Cases:"
    (grouped_summary[:skip] || []).each {|test_case| print_test_failure(test_case)}

    Log.notify("\n\n")

    Log.stdout = !options[:quiet]
    Log.file   = false
  end

  def print_test_failure(test_case)
    Log.notify "  Test Case #{test_case.path} reported: #{test_case.exception.inspect}"
  end

  def log_path(name)
    @@log_dir ||= File.join("log", @start_time.strftime("%F_%T"))
    unless File.directory?(@@log_dir) then
      FileUtils.mkdir(@@log_dir)
      FileUtils.cp(options[:config],(File.join(@@log_dir,"config.yml")))

      latest = File.join("log", "latest")
      if !File.exist?(latest) or File.symlink?(latest) then
        File.delete(latest) if File.exist?(latest)
        File.symlink(File.basename(@@log_dir), latest)
      end
    end

    File.join('log', 'latest', name)
  end

  # Setup log dir
  def initialize_logfiles
    return if options[:stdout_only]
    Log.file = log_path("#{name}-run.log")
  end
end
