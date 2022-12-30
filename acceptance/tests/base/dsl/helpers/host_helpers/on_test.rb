require "helpers/test_helper"

test_name "dsl::helpers::host_helpers #on" do

  step "#on raises an exception when remote command fails" do
    assert_raises(Beaker::Host::CommandFailure) do
      on default, "/bin/nonexistent-command"
    end
  end

  step "#on makes command output available via `.stdout` on success" do
    output = on(default, %Q{echo "echo via on"}).stdout
    assert_equal "echo via on\n", output
  end

  step "#on makes command error output available via `.stderr` on success" do
    output = on(default, "/bin/nonexistent-command", :acceptable_exit_codes => [0, 127]).stderr
    assert_match(/No such file/, output)
  end

  step "#on makes exit status available via `.exit_code`" do
    status = on(default, %Q{echo "echo via on"}).exit_code
    assert_equal 0, status
  end

  step "#on with :acceptable_exit_codes will not fail for named exit codes" do
    result = on default, "/bin/nonexistent-command", :acceptable_exit_codes => [0, 127]
    output = result.stderr
    assert_match(/No such file/, output)
    status = result.exit_code
    assert_equal 127, status
  end

  step "#on with :acceptable_exit_codes will fail for other exit codes" do
    assert_raises(Beaker::Host::CommandFailure) do
      on default, %Q{echo "echo via on"}, :acceptable_exit_codes => [127]
    end
  end

  step "#on will pass :environment options to the remote host as ENV settings" do
    result = on default, "env", { :environment => { 'FOO' => 'bar' } }
    output = result.stdout

    assert_match(/\bFOO=bar\b/, output)
  end

  step "#on runs command on all hosts when given a host array" do
    # Run a command which is (basically) guaranteed to have distinct output
    # on every host, and only requires bash to be present to run on any of
    # our platforms.
    results = on hosts, %Q{echo "${RANDOM}:${RANDOM}:${RANDOM}"}

    # assert that we got results back for every host
    assert_equal hosts.size, results.size

    # that they were all successful runs
    results.each do |result|
      assert_equal 0, result.exit_code
    end

    # and that we have |hosts| distinct outputs
    unique_outputs = results.map(&:output).uniq
    assert_equal hosts.size, unique_outputs.size
  end

  step "#on runs command on all hosts matching a role, when given a symbol" do
    # Run a command which is (basically) guaranteed to have distinct output
    # on every host, and only requires bash to be present to run on any of
    # our platforms.
    results = on :agent, %Q{echo "${RANDOM}:${RANDOM}:${RANDOM}"}

    # assert that we got results back for every host
    assert_equal hosts.size, results.size

    # that they were all successful runs
    results.each do |result|
      assert_equal 0, result.exit_code
    end

    # and that we have |hosts| distinct outputs
    unique_outputs = results.map(&:output).uniq
    assert_equal hosts.size, unique_outputs.size
  end

  step "#on runs command on all hosts matching a role, when given a string" do
    # Run a command which is (basically) guaranteed to have distinct output
    # on every host, and only requires bash to be present to run on any of
    # our platforms.
    results = on "agent", %Q{echo "${RANDOM}:${RANDOM}:${RANDOM}"}

    # assert that we got results back for every host
    assert_equal hosts.size, results.size

    # that they were all successful runs
    results.each do |result|
      assert_equal 0, result.exit_code
    end

    # and that we have |hosts| distinct outputs
    unique_outputs = results.map(&:output).uniq
    assert_equal hosts.size, unique_outputs.size
  end

  step "#on allows assertions to be used in the optional block" do
    on hosts, %Q{echo "${RANDOM}:${RANDOM}"} do
      assert_match(/\d+:\d+/, stdout)
    end
  end

  step "#on executes in parallel with :run_in_parallel => true" do
    parent_pid = Process.pid
    results = on( hosts, %Q{echo "${RANDOM}:${RANDOM}:${RANDOM}"}, :run_in_parallel => true) {
      assert(Process.pid != parent_pid)
    }

    # assert that we got results back for every host
    assert_equal hosts.size, results.size

    # that they were all successful runs
    results.each do |result|
      assert_equal 0, result.exit_code
    end

    # and that we have |hosts| distinct outputs
    unique_outputs = results.map(&:output).uniq
    assert_equal hosts.size, unique_outputs.size
  end

  step "#on in parallel exits after all processes complete if an exception is raised in one process" do
    start = Time.now

    tmp = nil
    assert_raises NoMethodError do
      on( hosts, %Q{echo "blah"}, :run_in_parallel => true) {
        sleep(1)
        tmp.blah
      }
    end
    assert(Time.now > start + 1)
  end
end
