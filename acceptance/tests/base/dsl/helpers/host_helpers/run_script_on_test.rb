require "helpers/test_helper"

test_name "dsl::helpers::host_helpers #run_script_on" do

  step "#run_script_on fails when the local script cannot be found" do
    assert_raises IOError do
      run_script_on default, "/non/existent/testfile.sh"
    end
  end

  step "#run_script_on fails when there is an error running the remote script" do
    Dir.mktmpdir do |local_dir|
      local_filename, _contents = create_local_file_from_fixture("failing_shell_script", local_dir, "testfile.sh", "a+x")

      assert_raises Beaker::Host::CommandFailure do
        run_script_on default, local_filename
      end
    end
  end

  step "#run_script_on passes along options when running the remote command" do
    Dir.mktmpdir do |local_dir|
      local_filename, _contents = create_local_file_from_fixture("failing_shell_script", local_dir, "testfile.sh", "a+x")

      result = run_script_on default, local_filename, { :accept_all_exit_codes => true }
      assert_equal 1, result.exit_code
    end
  end

  step "#run_script_on runs the script on the remote host" do
    Dir.mktmpdir do |local_dir|
      local_filename, _contents = create_local_file_from_fixture("shell_script_with_output", local_dir, "testfile.sh", "a+x")

      results = run_script_on default, local_filename
      assert_equal 0, results.exit_code
      assert_equal "output\n", results.stdout
    end
  end

  step "#run_script_on allows assertions in an optional block" do
    Dir.mktmpdir do |local_dir|
      local_filename, _contents = create_local_file_from_fixture("shell_script_with_output", local_dir, "testfile.sh", "a+x")

      run_script_on default, local_filename do
        assert_equal 0, exit_code
        assert_equal "output\n", stdout
      end
    end
  end

  step "#run_script_on runs the script on all remote hosts when a host array is provided" do
    Dir.mktmpdir do |local_dir|
      local_filename, _contents = create_local_file_from_fixture("shell_script_with_output", local_dir, "testfile.sh", "a+x")

      results = run_script_on hosts, local_filename

      assert_equal hosts.size, results.size
      results.each do |result|
        assert_equal 0, result.exit_code
        assert_equal "output\n", result.stdout
      end
    end
  end
end
