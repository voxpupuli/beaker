class Log
  class << self
    attr_accessor :log_level
    @log_level = :normal

    def debug(*args)
      puts *args if @log_level == :debug
    end

    def warn(*args)
      puts *args
    end

    def notify(*args)
      puts *args
    end

    def error(*args)
      puts *args
    end
  end

  def log_dir
    @log_dir ||= File.join("log", @start_time.strftime("%F_%T"))
  end

  # Setup log dir
  def initialize(options)
    @start_time = Time.now
    @results = []
    if options[:stdout_only]
      Log.debug "Will log to STDOUT, not files..."
      return
    end
    Log.debug "Writing logs to #{log_dir}/run.log"
    Log.debug
    FileUtils.mkdir(log_dir)
    FileUtils.cp(options[:config],(File.join(log_dir,"config.yml")))

    latest = File.join("log", "latest")
    File.delete(latest) if File.symlink?(latest)
    if File.exists?(latest)
      Log.warn "File log/latest is not a symlink; not overwriting"
    else
      File.symlink(File.basename(log_dir), latest)
    end

    log_file = File.join(log_dir, "run.log")
    run_log = File.new(log_file, "w")

    if ! options[:quiet]
      run_log = Tee.new(run_log)
    end

    $stdout = run_log
    $stderr = run_log
  end

  attr_reader :results
  def record_result(name, result)
    @results << [name, result]
  end

  def summarize(config, to_stdout)
    if to_stdout then
      Log.notify "\n\n"
    else
      sum_log = File.new(File.join(log_dir, "/summary.txt"), "w")
      $stdout = sum_log     # switch to logfile for output
      $stderr = sum_log
    end

    Log.notify <<-HEREDOC
  Test Pass Started: #{@start_time}

  - Host Configuration Summary -
    HEREDOC

    TestConfig.dump(config)

    test_count=0
    test_failed=0
    test_passed=0
    test_errored=0
    @results.each do |test, result|
      test_count += 1
      case result.test_status
      when :pass then test_passed += 1
      when :fail then test_failed += 1
      when :error then test_errored += 1
      end
    end
    grouped_summary = @results.group_by{|test,result| result.test_status }

    Log.notify <<-HEREDOC

  - Test Case Summary -
  Attempted: #{test_count}
     Passed: #{test_passed}
     Failed: #{test_failed}
     Errored: #{test_errored}

  - Specific Test Case Status -
  HEREDOC

    Log.notify "Failed Tests Cases:"
    (grouped_summary[:fail] || []).each {|test, result| print_test_failure(test, result)}

    Log.notify "Errored Tests Cases:"
    (grouped_summary[:error] || []).each {|test, result| print_test_failure(test, result)}

    sum_log.close unless to_stdout
  end

  def print_test_failure(test, result)
    Log.notify "  Test Case #{test} reported: #{result.exception.inspect}"
  end
end
