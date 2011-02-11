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

def summarize(test_summary, time, config, to_stdout)
  if to_stdout then
    puts "\n\n"
  else
    sum_log = File.new(File.join(log_dir(time), "/summary.txt"), "w")
    $stdout = sum_log     # switch to logfile for output
    $stderr = sum_log
  end
  puts "Test Pass Started: #{time}"
  puts
  puts "- Host Configuration Summary -"
  do_dump(config)

  test_count=0
  test_failed=0
  test_passed=0
  test_summary.each do |test, result|
    test_count+=1
    test_passed+=1 if (result==0)
    test_failed+=1 if (result!=0)
  end
  puts
  puts "- Test Case Summary -"
  puts "Attmpted: #{test_count}"
  puts "  Passed: #{test_passed}"
  puts "  Failed: #{test_failed}"
  puts
  puts "- Specific Test Case Status -"
  puts "Passed Tests Cases:"
  test_summary.each do |test|
    if ( test[1] == 0 )
      puts "  Test Case #{test[0]} reported: #{test[1]}"
    end
  end
  puts "Failed Tests Cases:"
  test_summary.each do |test|
    if ( test[1] != 0 )
      puts "  Test Case #{test[0]} reported: #{test[1]}"
    end
  end
  to_stdout or sum_log.close
end

