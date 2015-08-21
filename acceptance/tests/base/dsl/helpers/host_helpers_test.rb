test_name "dsl::helpers::host_helpers" do
  step "Validate hosts configuration" do
    assert (hosts.size > 1),
      "dsl::helpers::host_helpers acceptance tests require at least two hosts"

    agents = select_hosts(:roles => "agent")
    assert (agents.size > 1),
      "dsl::helpers::host_helpers acceptance tests require at least two hosts with the :agent role"
  end

  step "`on` raises an exception when remote command fails" do
    assert_raises(Beaker::Host::CommandFailure) do
      on hosts.first, "/bin/nonexistent-command"
    end
  end

  step "`on` makes command output available via `.stdout` on success" do
    output = on(hosts.first, %Q{echo "echo via on"}).stdout
    assert_equal "echo via on\n", output
  end

  step "`on` makes command error output available via `.stderr` on success" do
    output = on(hosts.first, "/bin/nonexistent-command", :acceptable_exit_codes => [0, 127]).stderr
    assert_match /No such file/, output
  end

  step "`on` makes exit status available via `.exit_code`" do
    status = on(hosts.first, %Q{echo "echo via on"}).exit_code
    assert_equal 0, status
  end

  step "`on` with :acceptable_exit_codes will not fail for named exit codes" do
    result = on hosts.first, "/bin/nonexistent-command", :acceptable_exit_codes => [0, 127]
    output = result.stderr
    assert_match /No such file/, output
    status = result.exit_code
    assert_equal 127, status
  end

  step "`on` with :acceptable_exit_codes will fail for other exit codes" do
    assert_raises(Beaker::Host::CommandFailure) do
      on hosts.first, %Q{echo "echo via on"}, :acceptable_exit_codes => [127]
    end
  end

  step "`on` will pass :environment options to the remote host as ENV settings" do
    result = on hosts.first, "env", { :environment => { 'FOO' => 'bar' } }
    output = result.stdout

    assert_match /\nFOO=bar\n/, output
  end

  step "`on` runs command on all hosts when given a host array" do
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

  step "`on` runs command on all hosts matching a role, when given a symbol" do
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

  step "`on` runs command on all hosts matching a role, when given a string" do
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

  step "`on` allows assertions to be used in the optional block" do
    on hosts, %Q{echo "${RANDOM}:${RANDOM}"} do
      assert_match /\d+:\d+/, stdout
    end
  end
end
