test_name "puppet master help should mention puppet master"
run_puppet_master_on(master, '--help') do
    fail_test "puppet master wasn't mentioned" unless stdout.include? 'puppet master'
end
