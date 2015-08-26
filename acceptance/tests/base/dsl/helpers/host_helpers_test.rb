require "fileutils"

# Currently scp failures throw a Net::SCP::Error exception in SSH connection
# close, which ends up not being caught properly, and which ultimately results
# in a RuntimeError. The SSH Connection is left in an unusable state and all
# later remote commands will hang indefinitely.
#
# TODO: fix this problem
def test_scp_error_on_close?
  !!ENV["TEST_SCP_ERROR_ON_CLOSE"]
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

  step "#on raises an exception when remote command fails" do
    assert_raises(Beaker::Host::CommandFailure) do
      on hosts.first, "/bin/nonexistent-command"
    end
  end

  step "#on makes command output available via `.stdout` on success" do
    output = on(hosts.first, %Q{echo "echo via on"}).stdout
    assert_equal "echo via on\n", output
  end

  step "#on makes command error output available via `.stderr` on success" do
    output = on(hosts.first, "/bin/nonexistent-command", :acceptable_exit_codes => [0, 127]).stderr
    assert_match /No such file/, output
  end

  step "#on makes exit status available via `.exit_code`" do
    status = on(hosts.first, %Q{echo "echo via on"}).exit_code
    assert_equal 0, status
  end

  step "#on with :acceptable_exit_codes will not fail for named exit codes" do
    result = on hosts.first, "/bin/nonexistent-command", :acceptable_exit_codes => [0, 127]
    output = result.stderr
    assert_match /No such file/, output
    status = result.exit_code
    assert_equal 127, status
  end

  step "#on with :acceptable_exit_codes will fail for other exit codes" do
    assert_raises(Beaker::Host::CommandFailure) do
      on hosts.first, %Q{echo "echo via on"}, :acceptable_exit_codes => [127]
    end
  end

  step "#on will pass :environment options to the remote host as ENV settings" do
    result = on hosts.first, "env", { :environment => { 'FOO' => 'bar' } }
    output = result.stdout

    assert_match /\nFOO=bar\n/, output
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
      assert_match /\d+:\d+/, stdout
    end
  end

  step "#shell raises an exception when remote command fails" do
    assert_raises(Beaker::Host::CommandFailure) do
      shell "/bin/nonexistent-command"
    end
  end

  step "#shell makes command output available via `.stdout` on success" do
    output = shell(%Q{echo "echo via on"}).stdout
    assert_equal "echo via on\n", output
  end

  step "#shell makes command error output available via `.stderr` on success" do
    output = shell("/bin/nonexistent-command", :acceptable_exit_codes => [0, 127]).stderr
    assert_match /No such file/, output
  end

  step "#shell makes exit status available via `.exit_code`" do
    status = shell(%Q{echo "echo via on"}).exit_code
    assert_equal 0, status
  end

  step "#shell with :acceptable_exit_codes will not fail for named exit codes" do
    result = shell "/bin/nonexistent-command", :acceptable_exit_codes => [0, 127]
    output = result.stderr
    assert_match /No such file/, output
    status = result.exit_code
    assert_equal 127, status
  end

  step "#shell with :acceptable_exit_codes will fail for other exit codes" do
    assert_raises(Beaker::Host::CommandFailure) do
      shell %Q{echo "echo via on"}, :acceptable_exit_codes => [127]
    end
  end

  step "#shell will pass :environment options to the remote host as ENV settings" do
    result = shell "env", { :environment => { 'FOO' => 'bar' } }
    output = result.stdout

    assert_match /\nFOO=bar\n/, output
  end

  step "#shell allows assertions to be used in the optional block" do
    shell %Q{echo "${RANDOM}:${RANDOM}"} do
      assert_match /\d+:\d+/, stdout
    end
  end

  step "#scp_to fails if the local file cannot be found" do
    remote_tmpdir = create_tmpdir_on hosts.first
    assert_raises IOError do
      scp_to hosts.first, "/non/existent/file.txt", remote_tmpdir
    end
  end

  if test_scp_error_on_close?
    step "#scp_to fails if the remote path cannot be found" do
      Dir.mktmpdir do |local_dir|
        local_filename = File.join(local_dir, "testfile.txt")
        File.open(local_filename, "w") do |local_file|
          local_file.puts "contents"
        end

        # assert_raises Beaker::Host::CommandFailure do
        assert_raises RuntimeError do
          scp_to hosts.first, local_filename, "/non/existent/remote/file.txt"
        end
      end
    end
  end

  step "#scp_to creates the file on the remote system" do
    Dir.mktmpdir do |local_dir|
      local_filename = File.join(local_dir, "testfile.txt")
      File.open(local_filename, "w") do |local_file|
        local_file.puts "contents"
      end
      remote_tmpdir = create_tmpdir_on hosts.first

      scp_to hosts.first, local_filename, remote_tmpdir

      remote_filename = File.join(remote_tmpdir, "testfile.txt")
      remote_contents = on(hosts.first, "cat #{remote_filename}").stdout
      assert_equal "contents\n", remote_contents
    end
  end

  step "#scp_to creates the file on all remote systems when a host array is provided" do
    Dir.mktmpdir do |local_dir|
      local_filename = File.join(local_dir, "testfile.txt")
      File.open(local_filename, "w") do |local_file|
        local_file.puts "contents"
      end

      remote_tmpdir = create_tmpdir_on hosts.first
      on hosts, "mkdir -p #{remote_tmpdir}"
      remote_filename = File.join(remote_tmpdir, "testfile.txt")

      scp_to hosts, local_filename, remote_tmpdir

      hosts.each do |host|
        remote_contents = on(host, "cat #{remote_filename}").stdout
        assert_equal "contents\n", remote_contents
      end
    end
  end

  if test_scp_error_on_close?
    step "#scp_from fails if the local path cannot be found" do
      remote_tmpdir = create_tmpdir_on hosts.first
      remote_filename = File.join(remote_tmpdir, "testfile.txt")
      on hosts.first, %Q{echo "contents" > #{remote_filename}}
      assert_raises Beaker::Host::CommandFailure do
        scp_from hosts.first, remote_filename, "/non/existent/file.txt"
      end
    end

    step "#scp_from fails if the remote file cannot be found" do
      Dir.mktmpdir do |local_dir|
        assert_raises Beaker::Host::CommandFailure do
          scp_from hosts.first, "/non/existent/remote/file.txt", local_dir
        end
      end
    end
  end

  step "#scp_from creates the file on the local system" do
    Dir.mktmpdir do |local_dir|
      remote_tmpdir = create_tmpdir_on hosts.first
      remote_filename = File.join(remote_tmpdir, "testfile.txt")
      on hosts.first, %Q{echo "contents" > #{remote_filename}}

      scp_from hosts.first, remote_filename, local_dir

      local_filename = File.join(local_dir, "testfile.txt")
      assert_equal "contents\n", File.read(local_filename)
    end
  end

  step "#scp_from CURRENTLY creates and repeatedly overwrites the file on the local system" do
    Dir.mktmpdir do |local_dir|
      local_filename = File.join(local_dir, "testfile.txt")
      remote_tmpdir = create_tmpdir_on hosts.first
      remote_filename = File.join(remote_tmpdir, "testfile.txt")
      on hosts, "mkdir -p #{remote_tmpdir}"
      results = on hosts, %Q{echo "${RANDOM}:${RANDOM}:${RANDOM}" > #{remote_filename}}

      scp_from hosts, remote_filename, local_dir

      remote_contents = on(hosts.last, "cat #{remote_filename}").stdout
      local_contents = File.read(local_filename)
      assert_equal remote_contents, local_contents
    end
  end

  step "#rsync_to fails if the local file cannot be found" do
    remote_tmpdir = create_tmpdir_on hosts.first
    assert_raises IOError do
      rsync_to hosts.first, "/non/existent/file.txt", remote_tmpdir
    end
  end

  step "#rsync_to CURRENTLY does not fail, but does not copy the file if the remote path cannot be found" do
    Dir.mktmpdir do |local_dir|
      local_filename = File.join(local_dir, "testfile.txt")
      File.open(local_filename, "w") do |local_file|
        local_file.puts "contents"
      end

      rsync_to hosts.first, local_filename, "/non/existent/testfile.txt"
      assert_raises Beaker::Host::CommandFailure do
        on(hosts.first, "cat /non/existent/testfile.txt").exit_code
      end
    end
  end

  step "#rsync_to creates the file on the remote system" do
    Dir.mktmpdir do |local_dir|
      local_filename = File.join(local_dir, "testfile.txt")
      File.open(local_filename, "w") do |local_file|
        local_file.puts "contents"
      end
      remote_tmpdir = create_tmpdir_on hosts.first

      rsync_to hosts.first, local_filename, remote_tmpdir

      remote_filename = File.join(remote_tmpdir, "testfile.txt")
      remote_contents = on(hosts.first, "cat #{remote_filename}").stdout
      assert_equal "contents\n", remote_contents
    end
  end

  step "#rsync_to creates the file on all remote systems when a host array is provided" do
    Dir.mktmpdir do |local_dir|
      local_filename = File.join(local_dir, "testfile.txt")
      File.open(local_filename, "w") do |local_file|
        local_file.puts "contents"
      end

      remote_tmpdir = create_tmpdir_on hosts.first
      on hosts, "mkdir -p #{remote_tmpdir}"
      remote_filename = File.join(remote_tmpdir, "testfile.txt")

      rsync_to hosts, local_filename, remote_tmpdir

      hosts.each do |host|
        remote_contents = on(host, "cat #{remote_filename}").stdout
        assert_equal "contents\n", remote_contents
      end
    end
  end

  if test_scp_error_on_close?
    step "#create_remote_file fails when the remote path does not exist" do
      assert_raises Beaker::Host::CommandFailure do
        create_remote_file hosts.first, "/non/existent/testfile.txt", "contents\n"
      end
    end

    step "#create_remote_file fails when the remote path does not exist, using scp" do
      assert_raises Beaker::Host::CommandFailure do
        create_remote_file hosts.first, "/non/existent/testfile.txt", "contents\n", { :protocol => 'scp' }
      end
    end
  end

  step "#create_remote_file CURRENTLY does not fail and does not create a remote file when the remote path does not exist, using rsync" do
    create_remote_file hosts.first, "/non/existent/testfile.txt", "contents\n", { :protocol => 'rsync' }
    assert_raises Beaker::Host::CommandFailure do
      on(hosts.first, "cat /non/existent/testfile.txt").exit_code
    end
  end

  step "#create_remote_file creates a remote file with the specified contents" do
    remote_tmpdir = create_tmpdir_on hosts.first
    remote_filename = File.join(remote_tmpdir, "testfile.txt")
    create_remote_file hosts.first, remote_filename, "contents\n"
    remote_contents = on(hosts.first, "cat #{remote_filename}").stdout
    assert_equal "contents\n", remote_contents
  end

  step "#create_remote_file creates a remote file with the specified contents, using scp" do
    remote_tmpdir = create_tmpdir_on hosts.first
    remote_filename = File.join(remote_tmpdir, "testfile.txt")
    create_remote_file hosts.first, remote_filename, "contents\n", { :protocol => "scp" }
    remote_contents = on(hosts.first, "cat #{remote_filename}").stdout
    assert_equal "contents\n", remote_contents
  end

  step "#create_remote_file creates a remote file with the specified contents, using rsync" do
    remote_tmpdir = create_tmpdir_on hosts.first
    remote_filename = File.join(remote_tmpdir, "testfile.txt")
    create_remote_file hosts.first, remote_filename, "contents\n", { :protocol => "rsync" }
    remote_contents = on(hosts.first, "cat #{remote_filename}").stdout
    assert_equal "contents\n", remote_contents
  end

  step "#create_remote_file' does not create a remote file when an unknown protocol is specified" do
    remote_tmpdir = create_tmpdir_on hosts.first
    remote_filename = File.join(remote_tmpdir, "testfile.txt")
    create_remote_file hosts.first, remote_filename, "contents\n", { :protocol => 'unknown' }
    assert_raises Beaker::Host::CommandFailure do
      on(hosts.first, "cat #{remote_filename}").exit_code
    end
  end

  step "#create_remote_file create remote files on all remote hosts, when given an array" do
    remote_tmpdir = create_tmpdir_on hosts.first
    on hosts, "mkdir -p #{remote_tmpdir}"
    remote_filename = File.join(remote_tmpdir, "testfile.txt")
    create_remote_file hosts, remote_filename, "contents\n"
    hosts.each do |host|
      remote_contents = on(host, "cat #{remote_filename}").stdout
      assert_equal "contents\n", remote_contents
    end
  end

  step "#create_remote_file create remote files on all remote hosts, when given an array, using scp" do
    remote_tmpdir = create_tmpdir_on hosts.first
    on hosts, "mkdir -p #{remote_tmpdir}"
    remote_filename = File.join(remote_tmpdir, "testfile.txt")
    create_remote_file hosts, remote_filename, "contents\n", { :protocol => 'scp' }
    hosts.each do |host|
      remote_contents = on(host, "cat #{remote_filename}").stdout
      assert_equal "contents\n", remote_contents
    end
  end

  step "#create_remote_file create remote files on all remote hosts, when given an array, using rsync" do
    remote_tmpdir = create_tmpdir_on hosts.first
    on hosts, "mkdir -p #{remote_tmpdir}"
    remote_filename = File.join(remote_tmpdir, "testfile.txt")
    create_remote_file hosts, remote_filename, "contents\n", { :protocol => 'rsync' }
    hosts.each do |host|
      remote_contents = on(host, "cat #{remote_filename}").stdout
      assert_equal "contents\n", remote_contents
    end
  end

  step "#run_script_on fails when the local script cannot be found" do
    assert_raises IOError do
      run_script_on hosts.first, "/non/existent/testfile.sh"
    end
  end

  step "#run_script_on fails when there is an error running the remote script" do
    Dir.mktmpdir do |local_dir|
      local_filename = File.join(local_dir, "testfile.sh")
      File.open(local_filename, "w") do |local_file|
        local_file.puts "exit 1"
      end
      FileUtils.chmod "a+x", local_filename

      assert_raises Beaker::Host::CommandFailure do
        run_script_on hosts.first, local_filename
      end
    end
  end

  step "#run_script_on passes along options when running the remote command" do
    Dir.mktmpdir do |local_dir|
      local_filename = File.join(local_dir, "testfile.sh")
      File.open(local_filename, "w") do |local_file|
        local_file.puts "exit 1"
      end
      FileUtils.chmod "a+x", local_filename

      result = run_script_on hosts.first, local_filename, { :accept_all_exit_codes => true }
      assert_equal 1, result.exit_code
    end
  end

  step "#run_script_on runs the script on the remote host" do
    Dir.mktmpdir do |local_dir|
      local_filename = File.join(local_dir, "testfile.sh")
      File.open(local_filename, "w") do |local_file|
        local_file.puts %Q{echo "contents"}
      end
      FileUtils.chmod "a+x", local_filename

      results = run_script_on hosts.first, local_filename
      assert_equal 0, results.exit_code
      assert_equal "contents\n", results.stdout
    end
  end

  step "#run_script_on allows assertions in an optional block" do
    Dir.mktmpdir do |local_dir|
      local_filename = File.join(local_dir, "testfile.sh")
      File.open(local_filename, "w") do |local_file|
        local_file.puts %Q{echo "contents"}
      end
      FileUtils.chmod "a+x", local_filename

      results = run_script_on hosts.first, local_filename do
        assert_equal 0, exit_code
        assert_equal "contents\n", stdout
      end
    end
  end

  step "#run_script_on runs the script on all remote hosts when a host array is provided" do
    Dir.mktmpdir do |local_dir|
      local_filename = File.join(local_dir, "testfile.sh")
      File.open(local_filename, "w") do |local_file|
        local_file.puts %Q{echo "contents"}
      end
      FileUtils.chmod "a+x", local_filename

      results = run_script_on hosts, local_filename

      assert_equal hosts.size, results.size
      results.each do |result|
        assert_equal 0, result.exit_code
        assert_equal "contents\n", result.stdout
      end
    end
  end

  step "#run_script fails when the local script cannot be found" do
    assert_raises IOError do
      run_script "/non/existent/testfile.sh"
    end
  end

  step "#run_script fails when there is an error running the remote script" do
    Dir.mktmpdir do |local_dir|
      local_filename = File.join(local_dir, "testfile.sh")
      File.open(local_filename, "w") do |local_file|
        local_file.puts "exit 1"
      end
      FileUtils.chmod "a+x", local_filename

      assert_raises Beaker::Host::CommandFailure do
        run_script local_filename
      end
    end
  end

  step "#run_script passes along options when running the remote command" do
    Dir.mktmpdir do |local_dir|
      local_filename = File.join(local_dir, "testfile.sh")
      File.open(local_filename, "w") do |local_file|
        local_file.puts "exit 1"
      end
      FileUtils.chmod "a+x", local_filename

      result = run_script local_filename, { :accept_all_exit_codes => true }
      assert_equal 1, result.exit_code
    end
  end

  step "#run_script runs the script on the remote host" do
    Dir.mktmpdir do |local_dir|
      local_filename = File.join(local_dir, "testfile.sh")
      File.open(local_filename, "w") do |local_file|
        local_file.puts %Q{echo "contents"}
      end
      FileUtils.chmod "a+x", local_filename

      results = run_script local_filename
      assert_equal 0, results.exit_code
      assert_equal "contents\n", results.stdout
    end
  end

  step "#run_script allows assertions in an optional block" do
    Dir.mktmpdir do |local_dir|
      local_filename = File.join(local_dir, "testfile.sh")
      File.open(local_filename, "w") do |local_file|
        local_file.puts %Q{echo "contents"}
      end
      FileUtils.chmod "a+x", local_filename

      results = run_script local_filename do
        assert_equal 0, exit_code
        assert_equal "contents\n", stdout
      end
    end
  end

  step "#install_package fails if package is not known on the OS" do
    assert_raises Beaker::Host::CommandFailure do
      install_package hosts.first, "non-existent-package-name"
    end
  end

  step "#install_package installs a known package successfully" do
    result = install_package hosts.first, "rsync"
    assert check_for_package(hosts.first, "rsync"), "package was not successfully installed"
  end

  step "#install_package succeeds when installing an already-installed package" do
    result = install_package hosts.first, "rsync"
    result = install_package hosts.first, "rsync"
    assert check_for_package(hosts.first, "rsync"), "package was not successfully installed"
  end

  step "#install_package CURRENTLY fails if given a host array" do
    assert_raises NoMethodError do
      install_package hosts, "rsync"
    end
  end

  step "#check_for_package will return false if the specified package is not installed on the remote host" do
    result = check_for_package hosts.first, "non-existent-package-name"
    assert !result
  end

  step "#check_for_package will return true if the specified package is installed on the remote host" do
    install_package hosts.first, "rsync"
    result = check_for_package hosts.first, "rsync"
    assert result
  end

  step "#check_for_package CURRENTLY fails if given a host array" do
    assert_raises NoMethodError do
      check_for_package hosts, "rsync"
    end
  end

  step "#upgrade_package fails if package is not already installed" do
    assert_raises Beaker::Host::CommandFailure do
      upgrade_package hosts.first, "non-existent-package-name"
    end
  end

  step "#upgrade_package succeeds if package is installed" do
    # TODO: anyone have any bright ideas on how to portably install an old
    # version of a package, to really test an upgrade?
    install_package hosts.first, "rsync"
    upgrade_package hosts.first, "rsync"
    assert check_for_package(hosts.first, "rsync"), "package was not successfully installed/upgraded"
  end

  step "#upgrade_package CURRENTLY fails when given a host array" do
    assert_raises NoMethodError do
      upgrade_package hosts, "rsync"
    end
  end

  step "#backup_the_file CURRENTLY will return nil if the file does not exist in the source directory" do
    remote_source = create_tmpdir_on hosts.first
    remote_destination = create_tmpdir_on hosts.first
    result = backup_the_file hosts.first, remote_source, remote_destination
    assert_nil result
  end

  step "#backup_the_file will fail if the destination directory does not exist" do
    remote_source = create_tmpdir_on hosts.first
    remote_source_filename = File.join(remote_source, "puppet.conf")
    create_remote_file hosts.first, remote_source_filename, "contents"

    assert_raises Beaker::Host::CommandFailure do
      result = backup_the_file hosts.first, remote_source, "/non/existent/"
    end
  end

  step "#backup_the_file copies `puppet.conf` from the source to the destination directory" do
    remote_source = create_tmpdir_on hosts.first
    remote_source_filename = File.join(remote_source, "puppet.conf")
    create_remote_file hosts.first, remote_source_filename, "contents"

    remote_destination = create_tmpdir_on hosts.first
    remote_destination_filename = File.join(remote_destination, "puppet.conf.bak")

    result = backup_the_file hosts.first, remote_source, remote_destination
    assert_equal remote_destination_filename, result
    contents = on(hosts.first, "cat #{remote_destination_filename}").stdout
    assert_equal "contents\n", contents
  end

  step "#backup_the_file copies a named file from the source to the destination directory" do
    remote_source = create_tmpdir_on hosts.first
    remote_source_filename = File.join(remote_source, "testfile.txt")
    create_remote_file hosts.first, remote_source_filename, "contents"
    remote_destination = create_tmpdir_on hosts.first
    remote_destination_filename = File.join(remote_destination, "testfile.txt.bak")

    result = backup_the_file hosts.first, remote_source, remote_destination, "testfile.txt"
    assert_equal remote_destination_filename, result
    contents = on(hosts.first, "cat #{remote_destination_filename}").stdout
    assert_equal "contents\n", contents
  end

  step "#backup_the_file CURRENTLY will fail if given a hosts array" do
    remote_source = create_tmpdir_on hosts.first
    remote_source_filename = File.join(remote_source, "testfile.txt")
    create_remote_file hosts.first, remote_source_filename, "contents"
    remote_destination = create_tmpdir_on hosts.first
    remote_destination_filename = File.join(remote_destination, "testfile.txt.bak")

    assert_raises NoMethodError do
      result = backup_the_file hosts, remote_source, remote_destination
    end
  end

  step "#curl_on fails if the URL in question cannot be reached" do
    assert Beaker::Host::CommandFailure do
      curl_on hosts.first, "file:///non/existent.html"
    end
  end

  step "#curl_on can retrieve the contents of a URL, using standard curl options" do
    remote_tmpdir = create_tmpdir_on hosts.first
    remote_filename = File.join remote_tmpdir, "testfile.txt"
    remote_targetfilename = File.join remote_tmpdir, "outfile.txt"
    create_remote_file hosts.first, remote_filename, "contents"
    result = curl_on hosts.first, "-o #{remote_targetfilename} file:///#{remote_filename}"
    assert_equal 0, result.exit_code
    remote_contents = on(hosts.first, "cat #{remote_targetfilename}").stdout
    assert_equal "contents\n", remote_contents
  end

  step "#curl_on can retrieve the contents of a URL, when given a hosts array" do
    remote_tmpdir = create_tmpdir_on hosts.first
    remote_filename = File.join remote_tmpdir, "testfile.txt"
    remote_targetfilename = File.join remote_tmpdir, "outfile.txt"
    on hosts, "mkdir -p #{remote_tmpdir}"
    create_remote_file hosts, remote_filename, "contents"

    result = curl_on hosts, "-o #{remote_targetfilename} file:///#{remote_filename}"

    hosts.each do |host|
      remote_contents = on(host, "cat #{remote_targetfilename}").stdout
      assert_equal "contents\n", remote_contents
    end
  end

  step "#curl_with_retries CURRENTLY fails with a RuntimeError if retries are exhausted without fetching the specified URL" do
    # NOTE: would expect that this would raise Beaker::Host::CommandFailure
    assert_raises RuntimeError do
      curl_with_retries \
        "description",
        hosts.first,
        "file:///non/existent.html",
        desired_exit_codes = [0],
        max_retries = 2,
        retry_interval = 0.01
    end
  end

  step "#curl_with_retries retrieves the contents of a URL after retrying" do
    # TODO: testing curl_with_retries relies on having a portable means of
    # making an unavailable URL available after a period of time.
  end

  step "#curl_with_retries can retrieve the contents of a URL after retrying, when given a hosts array" do
    # TODO: testing curl_with_retries relies on having a portable means of
    # making an unavailable URL available after a period of time.
  end

  step "#create_tmpdir_on returns a temporary directory on the remote system" do
    tmpdir = create_tmpdir_on hosts.first
    assert_match %r{/}, tmpdir
    assert_equal 0, on(hosts.first, "touch #{tmpdir}/testfile").exit_code
  end

  step "#create_tmpdir_on uses the specified path prefix when provided" do
    tmpdir = create_tmpdir_on(hosts.first, "mypathprefix")
    assert_match %r{/mypathprefix}, tmpdir
    assert_equal 0, on(hosts.first, "touch #{tmpdir}/testfile").exit_code
  end

  step "#create_tmpdir_on chowns the created tempdir to the host user + group" do
    tmpdir = create_tmpdir_on hosts.first
    listing = on(hosts.first, "ls -al #{tmpdir}").stdout
    tmpdir_ls = listing.split("\n").grep %r{\s+\./?\s*$}
    assert_equal 1, tmpdir_ls.size
    perms, inodes, owner, group, *rest = tmpdir_ls.first.split(/\s+/)
    assert_equal hosts.first['user'], owner
    assert_equal hosts.first['user'], group
  end

  step "#create_tmpdir_on fails if a non-existent user is specified" do
    assert_raises Beaker::Host::CommandFailure do
      tmpdir = create_tmpdir_on hosts.first, '', "fakeuser"
    end
  end

  step "#create_tmpdir_on operates on all hosts if given a hosts array" do
    tmpdirs = create_tmpdir_on hosts
    hosts.zip(tmpdirs).each do |(host, tmpdir)|
      assert_match %r{/}, tmpdir
      assert_equal 0, on(host, "touch #{tmpdir}/testfile").exit_code
    end
  end

  step "#create_tmpdir_on fails if the host platform is not supported" do
    # TODO - which platform(s) are not supported for create_tmpdir_on?
    # TODO - and, given that, how do we set up a sane test to exercise this?
  end

  step "#echo_on echoes the supplied string on the remote host" do
    output = echo_on(hosts.first, "contents")
    assert_equal output, "contents"
  end

  step "#echo_on echoes the supplied string on all hosts when given a hosts array" do
    results = echo_on(hosts, "contents")
    assert_equal ["contents"] * hosts.size, results
  end
end
