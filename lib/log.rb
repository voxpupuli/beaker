class Log
  def log_dir
    @log_dir ||= File.join("log", @start_time.strftime("%F_%T"))
  end

  # Setup log dir
  def initialize(options)
    @start_time = Time.now
    @results = []
    return if options[:stdout_only]
    puts "Writing logs to #{log_dir}/run.log"
    puts
    FileUtils.mkdir(log_dir)
    FileUtils.cp(options[:config],(File.join(log_dir,"config.yml")))

    latest = File.join("log", "latest")
    File.delete(latest) if File.symlink?(latest)
    if File.exists?(latest)
      puts "File log/latest is not a symlink; not overwriting"
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

  def record_result(name, result)
    @results << [name, result]
  end

  def summarize(config, to_stdout)
    if to_stdout then
      puts "\n\n"
    else
      sum_log = File.new(File.join(log_dir, "/summary.txt"), "w")
      $stdout = sum_log     # switch to logfile for output
      $stderr = sum_log
    end

    puts <<-HEREDOC
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

    puts <<-HEREDOC

  - Test Case Summary -
  Attempted: #{test_count}
     Passed: #{test_passed}
     Failed: #{test_failed}
     Errored: #{test_errored}

  - Specific Test Case Status -
  HEREDOC

    puts "Failed Tests Cases:"
    (grouped_summary[:fail] || []).each {|test, result| print_test_failure(test, result)}

    puts "Errored Tests Cases:"
    (grouped_summary[:error] || []).each {|test, result| print_test_failure(test, result)}

    sum_log.close unless to_stdout
  end

  def print_test_failure(test, result)
    puts "  Test Case #{test} reported: #{result.exception.inspect}"
  end
end
