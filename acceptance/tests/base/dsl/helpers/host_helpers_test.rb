
# Currently scp failures throw a Net::SCP::Error exception in SSH connection
# close, which ends up not being caught properly, and which ultimately results
# in a RuntimeError. The SSH Connection is left in an unusable state and all
# later remote commands will hang indefinitely.
#
# TODO: fix this problem
def test_scp_error_on_close?
  !!ENV['TEST_SCP_ERROR_ON_CLOSE']
end

test_name "dsl::helpers::host_helpers" do
  step "Validate hosts configuration" do
    assert (hosts.size > 1),
      "dsl::helpers::host_helpers acceptance tests require at least two hosts"

    agents = select_hosts(:roles => "agent")
    assert (agents.size > 1),
      "dsl::helpers::host_helpers acceptance tests require at least two hosts with the :agent role"

    assert default,
      "dsl::helpers::host_helpers acceptance tests require a default host"
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

  step "`shell` raises an exception when remote command fails" do
    assert_raises(Beaker::Host::CommandFailure) do
      shell "/bin/nonexistent-command"
    end
  end

  step "`shell` makes command output available via `.stdout` on success" do
    output = shell(%Q{echo "echo via on"}).stdout
    assert_equal "echo via on\n", output
  end

  step "`shell` makes command error output available via `.stderr` on success" do
    output = shell("/bin/nonexistent-command", :acceptable_exit_codes => [0, 127]).stderr
    assert_match /No such file/, output
  end

  step "`shell` makes exit status available via `.exit_code`" do
    status = shell(%Q{echo "echo via on"}).exit_code
    assert_equal 0, status
  end

  step "`shell` with :acceptable_exit_codes will not fail for named exit codes" do
    result = shell "/bin/nonexistent-command", :acceptable_exit_codes => [0, 127]
    output = result.stderr
    assert_match /No such file/, output
    status = result.exit_code
    assert_equal 127, status
  end

  step "`shell` with :acceptable_exit_codes will fail for other exit codes" do
    assert_raises(Beaker::Host::CommandFailure) do
      shell %Q{echo "echo via on"}, :acceptable_exit_codes => [127]
    end
  end

  step "`shell` will pass :environment options to the remote host as ENV settings" do
    result = shell "env", { :environment => { 'FOO' => 'bar' } }
    output = result.stdout

    assert_match /\nFOO=bar\n/, output
  end

  step "`shell` allows assertions to be used in the optional block" do
    shell %Q{echo "${RANDOM}:${RANDOM}"} do
      assert_match /\d+:\d+/, stdout
    end
  end

  step "`create_tmpdir_on` returns a temporary directory on the remote system" do
    tmpdir = create_tmpdir_on hosts.first
    assert_match %r{/}, tmpdir
    assert_equal 0, on(hosts.first, "touch #{tmpdir}/testfile").exit_code
  end

  step "`create_tmpdir_on` uses the specified path prefix when provided" do
    tmpdir = create_tmpdir_on(hosts.first, "mypathprefix")
    assert_match %r{/mypathprefix}, tmpdir
    assert_equal 0, on(hosts.first, "touch #{tmpdir}/testfile").exit_code
  end

  step "`create_tmpdir_on` chowns the created tempdir to the host user + group" do
    tmpdir = create_tmpdir_on hosts.first
    listing = on(hosts.first, "ls -al #{tmpdir}").stdout
    tmpdir_ls = listing.split("\n").grep %r{\s+\./?\s*$}
    assert_equal 1, tmpdir_ls.size
    perms, inodes, owner, group, *rest = tmpdir_ls.first.split(/\s+/)
    assert_equal hosts.first['user'], owner
    assert_equal hosts.first['user'], group
  end

  step "`create_tmpdir_on` fails if a non-existent user is specified" do
    assert_raises Beaker::Host::CommandFailure do
      tmpdir = create_tmpdir_on hosts.first, '', "fakeuser"
    end
  end

  step "`create_tmpdir_on` operates on all hosts if given a hosts array" do
    tmpdirs = create_tmpdir_on hosts
    hosts.zip(tmpdirs).each do |(host, tmpdir)|
      assert_match %r{/}, tmpdir
      assert_equal 0, on(host, "touch #{tmpdir}/testfile").exit_code
    end
  end

  step "`create_tmpdir_on` fails if the host platform is not supported" do
    # TODO - which platform(s) are not supported for create_tmpdir_on?
    # TODO - and, given that, how do we set up a sane test to exercise this?
  end

  step "`scp_to` fails if the local file cannot be found" do
    remotetmpdir = create_tmpdir_on hosts.first
    assert_raises IOError do
      scp_to hosts.first, "/non/existent/file.txt", remotetmpdir
    end
  end

  if test_scp_error_on_close?
    step "`scp_to` fails if the remote path cannot be found" do
      Dir.mktmpdir do |localdir|
        localfilename = File.join(localdir, "testfile.txt")
        File.open(localfilename, "w") do |localfile|
          localfile.puts "contents"
        end

        # assert_raises Beaker::Host::CommandFailure do
        assert_raises RuntimeError do
          scp_to hosts.first, localfilename, "/non/existent/remote/file.txt"
        end
      end
    end
  end

  step "`scp_to` creates the file on the remote system" do
    remotetmpdir = create_tmpdir_on hosts.first
    Dir.mktmpdir do |localdir|
      localfilename = File.join(localdir, "testfile.txt")
      File.open(localfilename, "w") do |localfile|
        localfile.puts "contents"
      end

      scp_to hosts.first, localfilename, remotetmpdir

      remotefilename = File.join(remotetmpdir, "testfile.txt")
      remote_contents = on(hosts.first, "cat #{remotefilename}").stdout
      assert_equal "contents\n", remote_contents
    end
  end

  if test_scp_error_on_close?
    step "`scp_from` fails if the local path cannot be found" do
      remotetmpdir = create_tmpdir_on hosts.first
      remotefilename = File.join(remotetmpdir, "testfile.txt")
      on hosts.first, %Q{echo "contents" > #{remotefilename}}
      assert_raises Beaker::Host::CommandFailure do
        scp_from hosts.first, remotefilename, "/non/existent/file.txt"
      end
    end

    step "`scp_from` fails if the remote file cannot be found" do
      Dir.mktmpdir do |localdir|
        assert_raises Beaker::Host::CommandFailure do
          scp_from hosts.first, "/non/existent/remote/file.txt", localdir
        end
      end
    end
  end

  step "`scp_from` creates the file on the local system" do
    Dir.mktmpdir do |localdir|
      remotetmpdir = create_tmpdir_on hosts.first
      remotefilename = File.join(remotetmpdir, "testfile.txt")
      on hosts.first, %Q{echo "contents" > #{remotefilename}}

      scp_from hosts.first, remotefilename, localdir

      localfilename = File.join(localdir, "testfile.txt")
      assert_equal "contents\n", File.read(localfilename)
    end
  end

  if test_scp_error_on_close?
    step "`create_remote_file` fails when the remote path does not exist" do
      assert_raises Beaker::Host::CommandFailure do
        create_remote_file hosts.first, "/non/existent/testfile.txt", "contents\n"
      end
    end

    step "`create_remote_file` fails when the remote path does not exist, using scp" do
      assert_raises Beaker::Host::CommandFailure do
        create_remote_file hosts.first, "/non/existent/testfile.txt", "contents\n", { :protocol => 'scp' }
      end
    end
  end

  step "`create_remote_file` CURRENTLY does not fail and does not create a remote file when the remote path does not exist, using rsync" do
    create_remote_file hosts.first, "/non/existent/testfile.txt", "contents\n", { :protocol => 'rsync' }
    assert_raises Beaker::Host::CommandFailure do
      on(hosts.first, "cat /non/existent/testfile.txt").exit_code
    end
  end

  step "`create_remote_file` creates a remote file with the specified contents" do
    remotetmpdir = create_tmpdir_on hosts.first
    remotefilename = File.join(remotetmpdir, "testfile.txt")
    create_remote_file hosts.first, remotefilename, "contents\n"
    remote_contents = on(hosts.first, "cat #{remotefilename}").stdout
    assert_equal "contents\n", remote_contents
  end

  step "`create_remote_file` creates a remote file with the specified contents, using scp" do
    remotetmpdir = create_tmpdir_on hosts.first
    remotefilename = File.join(remotetmpdir, "testfile.txt")
    create_remote_file hosts.first, remotefilename, "contents\n", { :protocol => "scp" }
    remote_contents = on(hosts.first, "cat #{remotefilename}").stdout
    assert_equal "contents\n", remote_contents
  end

  step "`create_remote_file` creates a remote file with the specified contents, using rsync" do
    remotetmpdir = create_tmpdir_on hosts.first
    remotefilename = File.join(remotetmpdir, "testfile.txt")
    create_remote_file hosts.first, remotefilename, "contents\n", { :protocol => "rsync" }
    remote_contents = on(hosts.first, "cat #{remotefilename}").stdout
    assert_equal "contents\n", remote_contents
  end

  step "`create_remote_file`' does not create a remote file when an unknown protocol is specified" do
    remotetmpdir = create_tmpdir_on hosts.first
    remotefilename = File.join(remotetmpdir, "testfile.txt")
    create_remote_file hosts.first, remotefilename, "contents\n", { :protocol => 'unknown' }
    assert_raises Beaker::Host::CommandFailure do
      on(hosts.first, "cat #{remotefilename}").exit_code
    end
  end

  step "`create_remote_file` create remote files on all remote hosts, when given an array" do
    remotetmpdir = create_tmpdir_on hosts.first
    on hosts, "mkdir -p #{remotetmpdir}"
    remotefilename = File.join(remotetmpdir, "testfile.txt")
    create_remote_file hosts, remotefilename, "contents\n"
    hosts.each do |host|
      remote_contents = on(host, "cat #{remotefilename}").stdout
      assert_equal "contents\n", remote_contents
    end
  end

  step "`create_remote_file` create remote files on all remote hosts, when given an array, using scp" do
    remotetmpdir = create_tmpdir_on hosts.first
    on hosts, "mkdir -p #{remotetmpdir}"
    remotefilename = File.join(remotetmpdir, "testfile.txt")
    create_remote_file hosts, remotefilename, "contents\n", { :protocol => 'scp' }
    hosts.each do |host|
      remote_contents = on(host, "cat #{remotefilename}").stdout
      assert_equal "contents\n", remote_contents
    end
  end

  step "`create_remote_file` create remote files on all remote hosts, when given an array, using rsync" do
    remotetmpdir = create_tmpdir_on hosts.first
    on hosts, "mkdir -p #{remotetmpdir}"
    remotefilename = File.join(remotetmpdir, "testfile.txt")
    create_remote_file hosts, remotefilename, "contents\n", { :protocol => 'rsync' }
    hosts.each do |host|
      remote_contents = on(host, "cat #{remotefilename}").stdout
      assert_equal "contents\n", remote_contents
    end
  end
end
