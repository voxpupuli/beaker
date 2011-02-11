def log_dir(time)
  File.join("log", time.strftime("%F_%T"))
end

# Setup log dir
def setup_logs(time, options)
  return if options[:stdout_only]
  puts "Writing logs to #{log_dir(time)}/run.log"
  puts
  FileUtils.mkdir(log_dir(time))
  FileUtils.cp(options[:config],(File.join(log_dir(time),"config.yml")))

  latest = File.join("log", "latest")
  File.delete(latest) if File.symlink?(latest)
  if File.exists?(latest)
    puts "File log/latest is not a symlink; not overwriting"
  else
    File.symlink(File.basename(log_dir(time)), latest)
  end

  log_file = File.join(log_dir(time), "run.log")
  run_log = File.new(log_file, "w")

  if ! options[:quiet]
    run_log = Tee.new(run_log)
  end

  $stdout = run_log
  $stderr = run_log
end

def test_printer(test)
  puts "  Test Case #{test[0]} reported: #{test[1]}"
end

def summarize(test_summary, time, config, to_stdout)
  if to_stdout then
    puts "\n\n"
  else
    sum_log = File.new(File.join(log_dir(time), "/summary.txt"), "w")
    $stdout = sum_log     # switch to logfile for output
    $stderr = sum_log
  end

  puts <<-HEREDOC
Test Pass Started: #{time}

- Host Configuration Summary -
  HEREDOC

  do_dump(config)

  test_count=0
  test_failed=0
  test_passed=0
  test_summary.each do |test, result|
    test_count+=1
    test_passed+=1 if (result==0)
    test_failed+=1 if (result!=0)
  end
  grouped_summary = test_summary.group_by{|test| test[1] == 0}

  puts <<-HEREDOC

- Test Case Summary -
Attempted: #{test_count}
   Passed: #{test_passed}
   Failed: #{test_failed}

- Specific Test Case Status -
Passed Tests Cases:
HEREDOC

  grouped_summary[true].each {|test| test_printer(test)}
  puts "Failed Tests Cases:"
  grouped_summary[false].each {|test| test_printer(test)}
  to_stdout or sum_log.close
end

