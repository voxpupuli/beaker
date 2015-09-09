require "fileutils"

# NOTE: Currently scp failures throw a Net::SCP::Error exception in SSH connection
# close, which ends up not being caught properly, and which ultimately results
# in a RuntimeError. The SSH Connection is left in an unusable state and all
# later remote commands will hang indefinitely.
#
# TODO: fix via: https://tickets.puppetlabs.com/browse/BKR-464
def test_scp_error_on_close?
  !!ENV["BEAKER_TEST_SCP_ERROR_ON_CLOSE"]
end

# NOTE: currently there is an issue with the tmpdir_on helper on cygwin
#       platforms:  the `chown` command always fails with an error about not
#       recognizing the Administrator:Administrator user/group.  Until this is
#       fixed, we add this shim that delegates to a non-`chown`-executing version
#       for the purposes of our test setup.
#
# TODO: fix via: https://tickets.puppetlabs.com/browse/BKR-496
def tmpdir_on(hosts, path_prefix = '', user=nil)
  return create_tmpdir_on(hosts, path_prefix, user) unless Array(hosts).first.is_cygwin?

  block_on hosts do | host |
    # use default user logged into this host
    if not user
      user = host['user']
    end

    if not on(host, "getent passwd #{user}").exit_code == 0
      raise "User #{user} does not exist on #{host}."
    end

    if defined? host.tmpdir
      # NOTE: here we skip the `chown` call:
      host.tmpdir(path_prefix)
    else
      raise "Host platform not supported by `tmpdir_on`."
    end
  end
end

# Returns the absolute path where file fixtures are located.
def fixture_path
  @fixture_path ||=
    File.expand_path(File.join(__FILE__, '..', '..', '..','..', '..', 'fixtures', 'files'))
end

# Returns the contents of a named fixture file, to be found in `fixture_path`.
def fixture_contents(fixture)
  fixture_file = File.join(fixture_path, "#{fixture}.txt")
  File.read(fixture_file)
end

# Create a file on `host` in the `remote_path` with file name `filename`,
# containing the contents of the fixture file named `fixture`.  Returns
# the full remote path to the created file.
def create_remote_file_from_fixture(fixture, host, remote_path, filename)
  full_filename = File.join(remote_path, filename)
  contents = fixture_contents fixture
  create_remote_file host, full_filename, contents
  [ full_filename, contents ]
end

# Create a file locally, in the `local_path`, with file name `filename`,
# containing the contents of the fixture file named `fixture`; optionally
# setting the file permissions to `perms`. Returns the full path to the created
# file, and the file contents.
def create_local_file_from_fixture(fixture, local_path, filename, perms = nil)
  full_filename = File.join(local_path, filename)
  contents = fixture_contents fixture

  File.open(full_filename, "w") do |local_file|
    local_file.puts contents
  end
  FileUtils.chmod perms, full_filename if perms

  [ full_filename, contents ]
end

test_name "dsl::helpers::host_helpers" do
  step "Validate hosts configuration" do
    # NOTE: to generate a suitable config, I use:
    #       `genconfig2 ${PLATFORM}-64default.a-64a`

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
      on default, "/bin/nonexistent-command"
    end
  end

  step "#on makes command output available via `.stdout` on success" do
    output = on(default, %Q{echo "echo via on"}).stdout
    assert_equal "echo via on\n", output
  end

  step "#on makes command error output available via `.stderr` on success" do
    output = on(default, "/bin/nonexistent-command", :acceptable_exit_codes => [0, 127]).stderr
    assert_match /No such file/, output
  end

  step "#on makes exit status available via `.exit_code`" do
    status = on(default, %Q{echo "echo via on"}).exit_code
    assert_equal 0, status
  end

  step "#on with :acceptable_exit_codes will not fail for named exit codes" do
    result = on default, "/bin/nonexistent-command", :acceptable_exit_codes => [0, 127]
    output = result.stderr
    assert_match /No such file/, output
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

    assert_match /\bFOO=bar\b/, output
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

    assert_match /\bFOO=bar\b/, output
  end

  step "#shell allows assertions to be used in the optional block" do
    shell %Q{echo "${RANDOM}:${RANDOM}"} do
      assert_match /\d+:\d+/, stdout
    end
  end

  step "#scp_to fails if the local file cannot be found" do
    remote_tmpdir = tmpdir_on default
    assert_raises IOError do
      scp_to default, "/non/existent/file.txt", remote_tmpdir
    end
  end

  if test_scp_error_on_close?
    step "#scp_to fails if the remote path cannot be found" do
      Dir.mktmpdir do |local_dir|
        local_filename, contents = create_local_file_from_fixture("simple_text_file", local_dir, "testfile.txt")

        # assert_raises Beaker::Host::CommandFailure do
        assert_raises RuntimeError do
          scp_to default, local_filename, "/non/existent/remote/file.txt"
        end
      end
    end
  end

  step "#scp_to creates the file on the remote system" do
    Dir.mktmpdir do |local_dir|
      local_filename, contents = create_local_file_from_fixture("simple_text_file", local_dir, "testfile.txt")
      remote_tmpdir = tmpdir_on default

      scp_to default, local_filename, remote_tmpdir

      remote_filename = File.join(remote_tmpdir, "testfile.txt")
      remote_contents = on(default, "cat #{remote_filename}").stdout
      assert_equal contents, remote_contents
    end
  end

  step "#scp_to creates the file on all remote systems when a host array is provided" do
    Dir.mktmpdir do |local_dir|
      local_filename, contents = create_local_file_from_fixture("simple_text_file", local_dir, "testfile.txt")

      remote_tmpdir = tmpdir_on default
      on hosts, "mkdir -p #{remote_tmpdir}"
      remote_filename = File.join(remote_tmpdir, "testfile.txt")

      scp_to hosts, local_filename, remote_tmpdir

      hosts.each do |host|
        remote_contents = on(host, "cat #{remote_filename}").stdout
        assert_equal contents, remote_contents
      end
    end
  end

  if test_scp_error_on_close?
    step "#scp_from fails if the local path cannot be found" do
      remote_tmpdir = tmpdir_on default
      remote_filename, contents = create_remote_file_from_fixture("simple_text_file", default, remote_tmpdir, "testfile.txt")

      assert_raises Beaker::Host::CommandFailure do
        scp_from default, remote_filename, "/non/existent/file.txt"
      end
    end

    step "#scp_from fails if the remote file cannot be found" do
      Dir.mktmpdir do |local_dir|
        assert_raises Beaker::Host::CommandFailure do
          scp_from default, "/non/existent/remote/file.txt", local_dir
        end
      end
    end
  end

  step "#scp_from creates the file on the local system" do
    Dir.mktmpdir do |local_dir|
      remote_tmpdir = tmpdir_on default
      remote_filename, contents = create_remote_file_from_fixture("simple_text_file", default, remote_tmpdir, "testfile.txt")

      scp_from default, remote_filename, local_dir

      local_filename = File.join(local_dir, "testfile.txt")
      assert_equal contents, File.read(local_filename)
    end
  end

  step "#scp_from CURRENTLY creates and repeatedly overwrites the file on the local system when given a hosts array" do
    # NOTE: expect this behavior to be well-documented, or for overwriting a
    #       file repeatedly to generate an error

    Dir.mktmpdir do |local_dir|
      remote_tmpdir = tmpdir_on default
      remote_filename = File.join(remote_tmpdir, "testfile.txt")
      on hosts, "mkdir -p #{remote_tmpdir}"
      results = on hosts, %Q{echo "${RANDOM}:${RANDOM}:${RANDOM}" > #{remote_filename}}

      scp_from hosts, remote_filename, local_dir
      remote_contents = on(hosts.last, "cat #{remote_filename}").stdout

      local_filename = File.join(local_dir, "testfile.txt")
      local_contents = File.read(local_filename)
      assert_equal remote_contents, local_contents
    end
  end

  confine_block :to, :platform => /^el-\d|solaris/ do

    step "#rsync_to CURRENTLY will fail without error, but not copy the requested file, on newly installed CentOS or Solaris due to lack of installed rsync" do
      Dir.mktmpdir do |local_dir|
        local_filename, contents = create_local_file_from_fixture("simple_text_file", local_dir, "testfile.txt")
        remote_tmpdir = tmpdir_on default

        rsync_to default, local_filename, remote_tmpdir

        remote_filename = File.join(remote_tmpdir, "testfile.txt")

        assert_raises Beaker::Host::CommandFailure do
          remote_contents = on(default, "cat #{remote_filename}").stdout
        end
      end
    end

    step "#create_remote_file with protocol 'rsync' fails on CentOS or Solaris due to lack of installed rsync" do
      remote_tmpdir = tmpdir_on default
      remote_filename = File.join(remote_tmpdir, "testfile.txt")
      contents = fixture_contents("simple_text_file")

      create_remote_file default, remote_filename, contents, { :protocol => "rsync" }

      assert_raises Beaker::Host::CommandFailure do
        remote_contents = on(default, "cat #{remote_filename}").stdout
      end
    end
  end

  confine_block :to, :platform => /^el-\d/ do
    step "installing `rsync` on CentOS for all later test steps" do
      hosts.each do |host|
        install_package host, "rsync"
      end
    end
  end

  # NOTE: there does not seem to be a reliable way to confine to cygwin hosts.
  confine_block :to, :platform => /windows/ do

    # NOTE: rsync methods are not working currently on windows platforms. Would
    #       expect this to be documented better.

    step "#rsync_to CURRENTLY fails on windows systems" do
      Dir.mktmpdir do |local_dir|
        local_filename, contents = create_local_file_from_fixture("simple_text_file", local_dir, "testfile.txt")
        remote_tmpdir = tmpdir_on default

        rsync_to default, local_filename, remote_tmpdir

        remote_filename = File.join(remote_tmpdir, "testfile.txt")
        assert_raises Beaker::Host::CommandFailure do
          remote_contents = on(default, "cat #{remote_filename}").stdout
        end
      end
    end
  end

  confine_block :except, :platform => /windows|solaris/ do

    step "#rsync_to fails if the local file cannot be found" do
      remote_tmpdir = tmpdir_on default
      assert_raises IOError do
        rsync_to default, "/non/existent/file.txt", remote_tmpdir
      end
    end

    step "#rsync_to CURRENTLY does not fail, but does not copy the file if the remote path cannot be found" do
      # NOTE: would expect this to fail with Beaker::Host::CommandFailure

      Dir.mktmpdir do |local_dir|
        local_filename, contents = create_local_file_from_fixture("simple_text_file", local_dir, "testfile.txt")

        rsync_to default, local_filename, "/non/existent/testfile.txt"
        assert_raises Beaker::Host::CommandFailure do
          on(default, "cat /non/existent/testfile.txt").exit_code
        end
      end
    end

    step "#rsync_to creates the file on the remote system" do
      Dir.mktmpdir do |local_dir|
        local_filename, contents = create_local_file_from_fixture("simple_text_file", local_dir, "testfile.txt")
        remote_tmpdir = tmpdir_on default

        rsync_to default, local_filename, remote_tmpdir

        remote_filename = File.join(remote_tmpdir, "testfile.txt")
        remote_contents = on(default, "cat #{remote_filename}").stdout
        assert_equal contents, remote_contents
      end
    end

    step "#rsync_to creates the file on all remote systems when a host array is provided" do
      Dir.mktmpdir do |local_dir|
        local_filename, contents = create_local_file_from_fixture("simple_text_file", local_dir, "testfile.txt")
        remote_tmpdir = tmpdir_on default
        on hosts, "mkdir -p #{remote_tmpdir}"
        remote_filename = File.join(remote_tmpdir, "testfile.txt")

        rsync_to hosts, local_filename, remote_tmpdir

        hosts.each do |host|
          remote_contents = on(host, "cat #{remote_filename}").stdout
          assert_equal contents, remote_contents
        end
      end
    end
  end

  if test_scp_error_on_close?
    step "#create_remote_file fails when the remote path does not exist" do
      assert_raises Beaker::Host::CommandFailure do
        create_remote_file default, "/non/existent/testfile.txt", "contents\n"
      end
    end

    step "#create_remote_file fails when the remote path does not exist, using scp" do
      assert_raises Beaker::Host::CommandFailure do
        create_remote_file default, "/non/existent/testfile.txt", "contents\n", { :protocol => 'scp' }
      end
    end
  end


  confine_block :to, :platform => /^el-4/ do

      step "#deploy_package_repo CURRENTLY does nothing and throws no error on the #{default['platform']} platform" do
        # NOTE: would expect this to fail with Beaker::Host::CommandFailure

        Dir.mktmpdir do |local_dir|
          name = "puppet-server"
          version = "9.9.9"
          platform = default['platform']

          local_filename, contents = create_local_file_from_fixture("simple_text_file", local_dir, "pl-#{name}-#{version}-repos-pe-#{platform}.repo")

          assert_nil deploy_package_repo(default, local_dir, name, version)
        end
      end
  end

  confine_block :to, :platform => /fedora|centos|eos|el-[56789]/i do

    step "#deploy_package_repo pushes repo package to /etc/yum.repos.d on the remote host" do
      Dir.mktmpdir do |local_dir|
        name = "puppet-server"
        version = "9.9.9"
        platform = default['platform']

        FileUtils.mkdir(File.join(local_dir, "rpm"))
        local_filename, contents = create_local_file_from_fixture("simple_text_file", File.join(local_dir, "rpm"), "pl-#{name}-#{version}-repos-pe-#{platform}.repo")

        deploy_package_repo default, local_dir, name, version

        remote_contents = on(default, "cat /etc/yum.repos.d/#{name}.repo").stdout
        assert_equal contents, remote_contents

        # teardown
        on default, "rm /etc/yum.repos.d/#{name}.repo"
      end
    end

    step "#deploy_package_repo CURRENTLY fails with NoMethodError when passed a hosts array" do
      # NOTE: would expect this to handle host arrays, or raise Beaker::Host::CommandFailure

      Dir.mktmpdir do |local_dir|
        name = "puppet-server"
        version = "9.9.9"
        platform = default['platform']

        local_filename, contents = create_local_file_from_fixture("simple_text_file", local_dir, "pl-#{name}-#{version}-repos-pe-#{platform}.repo")

        assert_raises NoMethodError do
          deploy_package_repo hosts, local_dir, name, version
        end
      end
    end
  end

  confine_block :to, :platform => /ubuntu|debian|cumulus/i do

    step "#deploy_package_repo pushes repo package to /etc/apt/sources.list.d on the remote host" do
      Dir.mktmpdir do |local_dir|
        name = "puppet-server"
        version = "9.9.9"
        codename = default['platform'].codename

        FileUtils.mkdir(File.join(local_dir, "deb"))
        local_filename, contents = create_local_file_from_fixture("simple_text_file", File.join(local_dir, "deb"), "pl-#{name}-#{version}-#{codename}.list")

        deploy_package_repo default, local_dir, name, version

        remote_contents = on(default, "cat /etc/apt/sources.list.d/#{name}.list").stdout
        assert_equal contents, remote_contents

        # teardown
        on default, "rm /etc/apt/sources.list.d/#{name}.list"
      end
    end

    step "#deploy_package_repo CURRENTLY fails with NoMethodError when passed a hosts array" do
      # NOTE: would expect this to handle host arrays, or raise Beaker::Host::CommandFailure

      Dir.mktmpdir do |local_dir|
        name = "puppet-server"
        version = "9.9.9"
        codename = default['platform'].codename

        FileUtils.mkdir(File.join(local_dir, "deb"))
        local_filename, contents = create_local_file_from_fixture("simple_text_file", File.join(local_dir, "deb"), "pl-#{name}-#{version}-#{codename}.list")

        assert_raises NoMethodError do
          deploy_package_repo hosts, local_dir, name, version
        end
      end
    end
  end

  confine_block :to, :platform => /sles/i do

    step "#deploy_package_repo updates zypper repository list on the remote host" do
      Dir.mktmpdir do |local_dir|
        name = "puppet-server"
        version = "9.9.9"
        platform = default['platform']

        FileUtils.mkdir(File.join(local_dir, "rpm"))
        local_filename, contents = create_local_file_from_fixture("sles-11-x86_64.repo", File.join(local_dir, "rpm"), "pl-#{name}-#{version}-repos-pe-#{platform}.repo")

        deploy_package_repo default, local_dir, name, version

        result = on default, "zypper repos -d"
        assert_match "PE-3.8-sles-11-x86_64", result.stdout

        # teardown
        on default, "zypper rr PE-3.8-sles-11-x86_64"
      end
    end
  end

  confine_block :except, :platform => /el-\d|fedora|centos|eos|ubuntu|debian|cumulus|sles/i do

    # OS X, windows (cygwin, powershell), solaris, etc.

    step "#deploy_package_repo CURRENTLY fails with a RuntimeError on on the #{default['platform']} platform" do
      # NOTE: would expect this to raise Beaker::Host::CommandFailure instead of RuntimeError

      Dir.mktmpdir do |local_dir|
        name = "puppet-server"
        version = "9.9.9"
        platform = default['platform']

        local_filename, contents = create_local_file_from_fixture("simple_text_file", local_dir, "pl-#{name}-#{version}-repos-pe-#{platform}.repo")

        assert_raises RuntimeError do
          deploy_package_repo default, local_dir, name, version
        end
      end
    end
  end

  step "#create_remote_file CURRENTLY does not fail and does not create a remote file when the remote path does not exist, using rsync" do
    # NOTE: would expect this to fail with Beaker::Host::CommandFailure

    create_remote_file default, "/non/existent/testfile.txt", "contents\n", { :protocol => 'rsync' }

    assert_raises Beaker::Host::CommandFailure do
      on(default, "cat /non/existent/testfile.txt").exit_code
    end
  end

  step "#create_remote_file creates a remote file with the specified contents" do
    remote_tmpdir = tmpdir_on default
    remote_filename = File.join(remote_tmpdir, "testfile.txt")
    contents = fixture_contents("simple_text_file")

    create_remote_file default, remote_filename, contents

    remote_contents = on(default, "cat #{remote_filename}").stdout
    assert_equal contents, remote_contents
  end

  step "#create_remote_file creates a remote file with the specified contents, using scp" do
    remote_tmpdir = tmpdir_on default
    remote_filename = File.join(remote_tmpdir, "testfile.txt")
    contents = fixture_contents("simple_text_file")

    create_remote_file default, remote_filename, contents, { :protocol => "scp" }

    remote_contents = on(default, "cat #{remote_filename}").stdout
    assert_equal contents, remote_contents
  end

  # NOTE: there does not seem to be a reliable way to confine to cygwin hosts.
  confine_block :to, :platform => /windows|solaris/ do

    # NOTE: rsync methods are not working currently on windows platforms

    step "#create_remote_file CURRENTLY fails on windows systems, using rsync" do
      remote_tmpdir = tmpdir_on default
      remote_filename = File.join(remote_tmpdir, "testfile.txt")
      contents = fixture_contents("simple_text_file")

      create_remote_file default, remote_filename, contents, { :protocol => "rsync" }

      assert_raises Beaker::Host::CommandFailure do
        remote_contents = on(default, "cat #{remote_filename}").stdout
      end
    end
  end

  confine_block :except, :platform => /windows|solaris/ do

    step "#create_remote_file creates a remote file with the specified contents, using rsync" do
      remote_tmpdir = tmpdir_on default
      remote_filename = File.join(remote_tmpdir, "testfile.txt")
      contents = fixture_contents("simple_text_file")

      create_remote_file default, remote_filename, contents, { :protocol => "rsync" }

      remote_contents = on(default, "cat #{remote_filename}").stdout
      assert_equal contents, remote_contents
    end
  end

  step "#create_remote_file' does not create a remote file when an unknown protocol is specified" do
    remote_tmpdir = tmpdir_on default
    remote_filename = File.join(remote_tmpdir, "testfile.txt")
    contents = fixture_contents("simple_text_file")

    create_remote_file default, remote_filename, contents, { :protocol => 'unknown' }

    assert_raises Beaker::Host::CommandFailure do
      on(default, "cat #{remote_filename}").exit_code
    end
  end

  step "#create_remote_file create remote files on all remote hosts, when given an array" do
    remote_tmpdir = tmpdir_on default
    on hosts, "mkdir -p #{remote_tmpdir}"
    remote_filename = File.join(remote_tmpdir, "testfile.txt")
    contents = fixture_contents("simple_text_file")

    create_remote_file hosts, remote_filename, contents

    hosts.each do |host|
      remote_contents = on(host, "cat #{remote_filename}").stdout
      assert_equal contents, remote_contents
    end
  end

  step "#create_remote_file create remote files on all remote hosts, when given an array, using scp" do
    remote_tmpdir = tmpdir_on default
    on hosts, "mkdir -p #{remote_tmpdir}"
    remote_filename = File.join(remote_tmpdir, "testfile.txt")
    contents = fixture_contents("simple_text_file")

    create_remote_file hosts, remote_filename, contents, { :protocol => 'scp' }

    hosts.each do |host|
      remote_contents = on(host, "cat #{remote_filename}").stdout
      assert_equal contents, remote_contents
    end
  end

  # NOTE: there does not appear to be a way to confine just to cygwin hosts
  confine_block :to, :platform => /windows|solaris/ do

    # NOTE: rsync methods are not working currently on windows platforms. Would
    #       expect this to be documented better.

    step "#create_remote_file create remote files on all remote hosts, when given an array, using rsync" do
      remote_tmpdir = tmpdir_on default
      on hosts, "mkdir -p #{remote_tmpdir}"
      remote_filename = File.join(remote_tmpdir, "testfile.txt")
      contents = fixture_contents("simple_text_file")

      create_remote_file hosts, remote_filename, contents, { :protocol => 'rsync' }

      hosts.each do |host|
        assert_raises Beaker::Host::CommandFailure do
          remote_contents = on(host, "cat #{remote_filename}").stdout
        end
      end
    end
  end

  confine_block :except, :platform => /windows|solaris/ do

    step "#create_remote_file create remote files on all remote hosts, when given an array, using rsync" do
      remote_tmpdir = tmpdir_on default
      on hosts, "mkdir -p #{remote_tmpdir}"
      remote_filename = File.join(remote_tmpdir, "testfile.txt")
      contents = fixture_contents("simple_text_file")

      create_remote_file hosts, remote_filename, contents, { :protocol => 'rsync' }

      hosts.each do |host|
        remote_contents = on(host, "cat #{remote_filename}").stdout
        assert_equal contents, remote_contents
      end
    end
  end

  confine_block :to, :platform => /centos|el-\d/ do

    step "uninstall rsync package on CentOS for later test runs" do
      # NOTE: this is basically a #teardown section for test isolation
      #       Could we reorganize tests into different files to make this
      #       clearer?

      hosts.each do |host|
        on host, "yum -y remove rsync"
      end
    end
  end

  step "#run_script_on fails when the local script cannot be found" do
    assert_raises IOError do
      run_script_on default, "/non/existent/testfile.sh"
    end
  end

  step "#run_script_on fails when there is an error running the remote script" do
    Dir.mktmpdir do |local_dir|
      local_filename = File.join(local_dir, "testfile.sh")
      local_filename, contents = create_local_file_from_fixture("failing_shell_script", local_dir, "testfile.sh", "a+x")

      assert_raises Beaker::Host::CommandFailure do
        run_script_on default, local_filename
      end
    end
  end

  step "#run_script_on passes along options when running the remote command" do
    Dir.mktmpdir do |local_dir|
      local_filename = File.join(local_dir, "testfile.sh")
      local_filename, contents = create_local_file_from_fixture("failing_shell_script", local_dir, "testfile.sh", "a+x")

      result = run_script_on default, local_filename, { :accept_all_exit_codes => true }
      assert_equal 1, result.exit_code
    end
  end

  step "#run_script_on runs the script on the remote host" do
    Dir.mktmpdir do |local_dir|
      local_filename = File.join(local_dir, "testfile.sh")
      local_filename, contents = create_local_file_from_fixture("shell_script_with_output", local_dir, "testfile.sh", "a+x")

      results = run_script_on default, local_filename
      assert_equal 0, results.exit_code
      assert_equal "output\n", results.stdout
    end
  end

  step "#run_script_on allows assertions in an optional block" do
    Dir.mktmpdir do |local_dir|
      local_filename = File.join(local_dir, "testfile.sh")
      local_filename, contents = create_local_file_from_fixture("shell_script_with_output", local_dir, "testfile.sh", "a+x")

      results = run_script_on default, local_filename do
        assert_equal 0, exit_code
        assert_equal "output\n", stdout
      end
    end
  end

  step "#run_script_on runs the script on all remote hosts when a host array is provided" do
    Dir.mktmpdir do |local_dir|
      local_filename = File.join(local_dir, "testfile.sh")
      local_filename, contents = create_local_file_from_fixture("shell_script_with_output", local_dir, "testfile.sh", "a+x")

      results = run_script_on hosts, local_filename

      assert_equal hosts.size, results.size
      results.each do |result|
        assert_equal 0, result.exit_code
        assert_equal "output\n", result.stdout
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
      local_filename, contents = create_local_file_from_fixture("failing_shell_script", local_dir, "testfile.sh", "a+x")

      assert_raises Beaker::Host::CommandFailure do
        run_script local_filename
      end
    end
  end

  step "#run_script passes along options when running the remote command" do
    Dir.mktmpdir do |local_dir|
      local_filename = File.join(local_dir, "testfile.sh")
      local_filename, contents = create_local_file_from_fixture("failing_shell_script", local_dir, "testfile.sh", "a+x")

      result = run_script local_filename, { :accept_all_exit_codes => true }
      assert_equal 1, result.exit_code
    end
  end

  step "#run_script runs the script on the remote host" do
    Dir.mktmpdir do |local_dir|
      local_filename = File.join(local_dir, "testfile.sh")
      local_filename, contents = create_local_file_from_fixture("shell_script_with_output", local_dir, "testfile.sh", "a+x")

      results = run_script local_filename
      assert_equal 0, results.exit_code
      assert_equal "output\n", results.stdout
    end
  end

  step "#run_script allows assertions in an optional block" do
    Dir.mktmpdir do |local_dir|
      local_filename = File.join(local_dir, "testfile.sh")
      local_filename, contents = create_local_file_from_fixture("shell_script_with_output", local_dir, "testfile.sh", "a+x")

      results = run_script local_filename do
        assert_equal 0, exit_code
        assert_equal "output\n", stdout
      end
    end
  end

  # NOTE: there does not appear to be a way to confine just to cygwin hosts
  confine_block :to, :platform => /solaris/ do

    # NOTE: install_package, check_for_package, and upgrade_package on windows
    # currently fail as follows:
    #
    #       ArgumentError: wrong number of arguments (3 for 1..2)
    #
    #       Would expect this to be documented better, and to fail with Beaker::Host::CommandFailure

    step "#install_package CURRENTLY fails on solaris platforms" do
      assert_raises Beaker::Host::CommandFailure do
        install_package default, "rsync"
      end
    end

    step "#check_for_package will return false if the specified package is not installed on the remote host" do
      result = check_for_package default, "non-existent-package-name"
      assert !result
    end

    step "#check_for_package will return true if the specified package is installed on the remote host" do
      result = check_for_package default, "SUNWbash"
      assert result
    end

    step "#check_for_package CURRENTLY fails if given a host array" do
      assert_raises NoMethodError do
        check_for_package hosts, "rsync"
      end
    end

    step "#upgrade_package CURRENTLY fails on solaris platforms" do
      # NOTE: pkgutil doesn't appear to be installed by default -- documentation
      #       could be better here.
      assert_raises Beaker::Host::CommandFailure do
        upgrade_package default, "bash"
      end
    end
  end

  # NOTE: there does not appear to be a way to confine just to cygwin hosts
  confine_block :to, :platform => /windows/ do

    # NOTE: install_package, check_for_package, and upgrade_package on windows
    # currently fail as follows:
    #
    #       ArgumentError: wrong number of arguments (3 for 1..2)
    #
    #       Would expect this to be documented better, and to fail with Beaker::Host::CommandFailure

    step "#install_package CURRENTLY fails on windows platforms" do
      assert_raises ArgumentError do
        install_package default, "rsync"
      end
    end

    step "#check_for_package will return false if the specified package is not installed on the remote host" do
      result = check_for_package default, "non-existent-package-name"
      assert !result
    end

    step "#check_for_package will return true if the specified package is installed on the remote host" do
      result = check_for_package default, "bash"
      assert result
    end

    step "#check_for_package CURRENTLY fails if given a host array" do
      assert_raises NoMethodError do
        check_for_package hosts, "rsync"
      end
    end

    step "#upgrade_package CURRENTLY fails on windows platforms with a RuntimeError" do
      # NOTE: this is not a supported platform but would expect a Beaker::Host::CommandFailure
      assert_raises RuntimeError do
        upgrade_package default, "bash"
      end
    end
  end

  confine_block :except, :platform => /windows|solaris/ do

    step "#install_package fails if package is not known on the OS" do
      assert_raises Beaker::Host::CommandFailure do
        install_package default, "non-existent-package-name"
      end
    end

    step "#install_package installs a known package successfully" do
      result = install_package default, "rsync"
      assert check_for_package(default, "rsync"), "package was not successfully installed"
    end

    step "#install_package succeeds when installing an already-installed package" do
      result = install_package default, "rsync"
      result = install_package default, "rsync"
      assert check_for_package(default, "rsync"), "package was not successfully installed"
    end

    step "#install_package CURRENTLY fails if given a host array" do
      # NOTE: would expect this to work across hosts, or to be better
      #       documented. If not supported, should raise
      #       Beaker::Host::CommandFailure

      assert_raises NoMethodError do
        install_package hosts, "rsync"
      end
    end

    step "#check_for_package will return false if the specified package is not installed on the remote host" do
      result = check_for_package default, "non-existent-package-name"
      assert !result
    end

    step "#check_for_package will return true if the specified package is installed on the remote host" do
      install_package default, "rsync"
      result = check_for_package default, "rsync"
      assert result
    end

    step "#check_for_package CURRENTLY fails if given a host array" do
      # NOTE: would expect this to work across hosts, or to be better
      #       documented. If not supported, should raise
      #       Beaker::Host::CommandFailure

      assert_raises NoMethodError do
        check_for_package hosts, "rsync"
      end
    end

    confine_block :to, :platform => /centos|el-\d/ do

      step "#upgrade_package CURRENTLY does not fail on CentOS if unknown package is specified" do
        # NOTE: I would expect this to fail with an Beaker::Host::CommandFailure,
        #       but maybe it's because yum doesn't really care:
        #
        #       > Loaded plugins: fastestmirror
        #       > Loading mirror speeds from cached hostfile
        #       > Setting up Update Process
        #       > No package non-existent-package-name available.
        #       > No Packages marked for Update

        result = upgrade_package default, "non-existent-package-name"
        assert_match /No Packages marked for Update/, result
      end
    end

    confine_block :except, :platform => /centos|el-\d/ do

      step "#upgrade_package fails if package is not already installed" do
        assert_raises Beaker::Host::CommandFailure do
          upgrade_package default, "non-existent-package-name"
        end
      end
    end

    step "#upgrade_package succeeds if package is installed" do
      # TODO: anyone have any bright ideas on how to portably install an old
      # version of a package, to really test an upgrade?

      install_package default, "rsync"
      upgrade_package default, "rsync"
      assert check_for_package(default, "rsync"), "package was not successfully installed/upgraded"
    end

    step "#upgrade_package CURRENTLY fails when given a host array" do
      # NOTE: would expect this to work across hosts, or to be better documented,
      #       if not support, should raise Beaker::Host::CommandFailure

      assert_raises NoMethodError do
        upgrade_package hosts, "rsync"
      end
    end
  end

  confine_block :to, :platform => /windows/ do

    step "#add_system32_hosts_entry fails when run on a non-powershell platform" do
      # NOTE: would expect this to be better documented.
      #       Also, this method should probably live outside the core hosts helpers,
      #       and should probably be a more generalized method.
      if default.is_powershell?
        logger.info "Skipping failure test on powershell platforms..."
      else
        assert_raises Beaker::Host::CommandFailure do
          add_system32_hosts_entry default, { :ip => '123.45.67.89', :name => 'beaker.puppetlabs.com' }
        end
      end
    end

    step "#add_system32_hosts_entry, when run on a powershell platform, adds a host entry to system32 etc\\hosts" do
      if default.is_powershell?
        add_system32_hosts_entry default, { :ip => '123.45.67.89', :name => 'beaker.puppetlabs.com' }

        # TODO: how do we assert, via powershell, that the entry was added?
        # NOTE: see: https://github.com/puppetlabs/beaker/commit/685628f4babebe9cb4663418da6a8ff528dd32da#commitcomment-12957573

      else
        logger.info "Skipping test on non-powershell platforms..."
      end
    end

    step "#add_system32_hosts_entry CURRENTLY fails with a TypeError when given a hosts array" do
      # NOTE: would expect this to fail with Beaker::Host::CommandFailure
      assert_raises TypeError do
        add_system32_hosts_entry hosts, { :ip => '123.45.67.89', :name => 'beaker.puppetlabs.com' }
      end
    end
  end

  confine_block :except, :platform => /windows/ do

    step "#add_system32_hosts_entry CURRENTLY fails with RuntimeError when run on a non-windows platform" do
      # NOTE: would expect this to behave the same way it does on a windows
      #       non-powershell platform (raises Beaker::Host::CommandFailure), or
      #       as requested in the original PR:
      #       https://github.com/puppetlabs/beaker/pull/420/files#r17990622
      assert_raises RuntimeError do
        add_system32_hosts_entry default, { :ip => '123.45.67.89', :name => 'beaker.puppetlabs.com' }
      end
    end
  end

  step "#backup_the_file CURRENTLY will return nil if the file does not exist in the source directory" do
    # NOTE: would expect this to fail with Beaker::Host::CommandFailure
    remote_source = tmpdir_on default
    remote_destination = tmpdir_on default
    result = backup_the_file default, remote_source, remote_destination
    assert_nil result
  end

  step "#backup_the_file will fail if the destination directory does not exist" do
    remote_source = tmpdir_on default
    remote_source_filename = File.join(remote_source, "puppet.conf")
    remote_filename, contents = create_remote_file_from_fixture("simple_text_file", default, remote_source, "puppet.conf")

    assert_raises Beaker::Host::CommandFailure do
      result = backup_the_file default, remote_source, "/non/existent/"
    end
  end

  step "#backup_the_file copies `puppet.conf` from the source to the destination directory" do
    remote_source = tmpdir_on default
    remote_source_filename = File.join(remote_source, "puppet.conf")
    remote_filename, contents = create_remote_file_from_fixture("simple_text_file", default, remote_source, "puppet.conf")

    remote_destination = tmpdir_on default
    remote_destination_filename = File.join(remote_destination, "puppet.conf.bak")

    result = backup_the_file default, remote_source, remote_destination

    assert_equal remote_destination_filename, result
    remote_contents = on(default, "cat #{remote_destination_filename}").stdout
    assert_equal contents, remote_contents
  end

  step "#backup_the_file copies a named file from the source to the destination directory" do
    remote_source = tmpdir_on default
    remote_source_filename = File.join(remote_source, "testfile.txt")
    remote_filename, contents = create_remote_file_from_fixture("simple_text_file", default, remote_source, "testfile.txt")

    remote_destination = tmpdir_on default
    remote_destination_filename = File.join(remote_destination, "testfile.txt.bak")

    result = backup_the_file default, remote_source, remote_destination, "testfile.txt"

    assert_equal remote_destination_filename, result
    remote_contents = on(default, "cat #{remote_destination_filename}").stdout
    assert_equal contents, remote_contents
  end

  step "#backup_the_file CURRENTLY will fail if given a hosts array" do
    remote_source = tmpdir_on default
    remote_source_filename = File.join(remote_source, "testfile.txt")
    remote_filename, contents = create_remote_file_from_fixture("simple_text_file", default, remote_source, "testfile.txt")
    remote_destination = tmpdir_on default

    remote_destination_filename = File.join(remote_destination, "testfile.txt.bak")

    assert_raises NoMethodError do
      result = backup_the_file hosts, remote_source, remote_destination
    end
  end

  step "#curl_on fails if the URL in question cannot be reached" do
    assert Beaker::Host::CommandFailure do
      curl_on default, "file:///non/existent.html"
    end
  end

  # construct an appropriate local file URL for curl testing
  def host_local_url(host, path)
    if host.is_cygwin?
      "file://#{path.gsub('/', '\\\\\\\\')}"
    else
      "file://#{path}"
    end
  end

  step "#curl_on can retrieve the contents of a URL, using standard curl options" do
    remote_tmpdir = tmpdir_on default
    remote_filename, contents = create_remote_file_from_fixture("simple_text_file", default, remote_tmpdir, "testfile.txt")
    remote_targetfilename = File.join remote_tmpdir, "outfile.txt"

    result = curl_on default, "-o #{remote_targetfilename} #{host_local_url default, remote_filename}"

    assert_equal 0, result.exit_code
    remote_contents = on(default, "cat #{remote_targetfilename}").stdout
    assert_equal contents, remote_contents
  end

  step "#curl_on can retrieve the contents of a URL, when given a hosts array" do
    remote_tmpdir = tmpdir_on default
    on hosts, "mkdir -p #{remote_tmpdir}"

    remote_filename = contents = nil
    hosts.each do |host|
      remote_filename, contents = create_remote_file_from_fixture("simple_text_file", host, remote_tmpdir, "testfile.txt")
    end
    remote_targetfilename = File.join remote_tmpdir, "outfile.txt"

    result = curl_on hosts, "-o #{remote_targetfilename} #{host_local_url default, remote_filename}"

    hosts.each do |host|
      remote_contents = on(host, "cat #{remote_targetfilename}").stdout
      assert_equal contents, remote_contents
    end
  end

  step "#curl_with_retries CURRENTLY fails with a RuntimeError if retries are exhausted without fetching the specified URL" do
    # NOTE: would expect that this would raise Beaker::Host::CommandFailure

    assert_raises RuntimeError do
      curl_with_retries \
        "description",
        default,
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

  step "#retry_on CURRENTLY fails with a RuntimeError if command does not pass after all retries" do
    # NOTE: would have expected this to fail with Beaker::Hosts::CommandFailure

    remote_tmpdir = tmpdir_on default
    remote_script_file = File.join(remote_tmpdir, "test.sh")
    remote_filename, contents = create_remote_file_from_fixture("retry_script", default, remote_tmpdir, "test.sh")

    assert_raises RuntimeError do
      retry_on default, "bash #{remote_script_file} #{remote_tmpdir} 10", { :max_retries => 2, :retry_interval => 0.1 }
    end
  end

  step "#retry_on succeeds if command passes before retries are exhausted" do
    remote_tmpdir = tmpdir_on default
    remote_script_file = File.join(remote_tmpdir, "test.sh")
    remote_filename, contents = create_remote_file_from_fixture("retry_script", default, remote_tmpdir, "test.sh")

    result = retry_on default, "bash #{remote_script_file} #{remote_tmpdir} 2", { :max_retries => 4, :retry_interval => 0.1 }
    assert_equal 0, result.exit_code
    assert_equal "", result.stdout
  end

  step "#retry_on CURRENTLY fails when provided a host array" do
    # NOTE: would expect this to work across hosts, or be better documented and
    #       to raise Beaker::Host::CommandFailure

    remote_tmpdir = tmpdir_on default
    remote_script_file = File.join(remote_tmpdir, "test.sh")

    hosts.each do |host|
      on host, "mkdir -p #{remote_tmpdir}"
      remote_filename, contents = create_remote_file_from_fixture("retry_script", host, remote_tmpdir, "test.sh")
    end

    assert_raises NoMethodError do
      result = retry_on hosts, "bash #{remote_script_file} #{remote_tmpdir} 2", { :max_retries => 4, :retry_interval => 0.1 }
    end
  end

  confine_block :to, :platform => /windows/ do

    step "#run_cron_on fails on windows platforms when listing cron jobs for a user on a host" do
      assert_raises Beaker::Host::CommandFailure do
        run_cron_on default, :list, default['user']
      end
    end
  end

  confine_block :to, :platform => /solaris/ do

    step "#run_cron_on CURRENTLY does nothing and returns `nil` when an unknown command is provided" do
      # NOTE: would have expected this to raise Beaker::Host::CommandFailure instead

      assert_nil run_cron_on default, :nonexistent_action, default['user']
    end

    step "#run_cron_on CURRENTLY does not fail when listing cron jobs for an unknown user" do
      assert_raises Beaker::Host::CommandFailure do
        run_cron_on default, :list, "nonexistentuser"
      end
    end

    step "#run_cron_on CURRENTLY does not fail when listing cron jobs for a user with no cron entries" do
      result = run_cron_on default, :list, default['user']
      assert_equal 0, result.exit_code
    end

    step "#run_cron_on returns a list of cron jobs for a user with cron entries" do
      # this basically requires us to add a cron entry to make this work
      run_cron_on default, :add, default['user'], "* * * * * /bin/ls >/dev/null"
      result = run_cron_on default, :list, default['user']
      assert_equal 0, result.exit_code
      assert_match %r{/bin/ls}, result.stdout
    end

    step "#run_cron_on CURRENTLY does not fail, but returns nil, when adding cron jobs for an unknown user" do
      result = run_cron_on default, :add, "nonexistentuser", %Q{* * * * * /bin/echo "hello" >/dev/null}
      assert_nil result
    end

    step "#run_cron_on CURRENTLY does not fail, but returns nil, when attempting to add a bad cron entry" do
      result = run_cron_on default, :add, default['user'], "* * * * /bin/ls >/dev/null"
      assert_nil result
    end

    step "#run_cron_on can add a cron job for a user on a host" do
      run_cron_on default, :add, default['user'], %Q{* * * * * /bin/echo "hello" >/dev/null}
      result = run_cron_on default, :list, default['user']
      assert_equal 0, result.exit_code
      assert_match %r{/bin/echo}, result.stdout
    end

    step "#run_cron_on CURRENTLY replaces all of user's cron jobs with any newly added jobs" do
      # NOTE: would have expected this to append new entries, or manage them as puppet manages
      #       cron entries.  See also: https://github.com/puppetlabs/beaker/pull/937#discussion_r38338494

      1.upto(3) do |job_number|
        run_cron_on default, :add, default['user'], %Q{* * * * * /bin/echo "job :#{job_number}:" >/dev/null}
      end

      result = run_cron_on default, :list, default['user']

      assert_no_match %r{job :1:}, result.stdout
      assert_no_match %r{job :2:}, result.stdout
      assert_match %r{job :3:}, result.stdout
    end

    step "#run_cron_on :remove CURRENTLY removes all cron jobs for a user on a host" do
      # NOTE: would have expected a more granular approach to removing cron jobs
      #       for a user on a host.  This should otherwise be better documented.

      run_cron_on default, :add, default['user'], %Q{* * * * * /bin/echo "quality: job 1" >/dev/null}
      result = run_cron_on default, :list, default['user']
      assert_match %r{quality: job 1}, result.stdout

      run_cron_on default, :remove, default['user']

      assert_raises Beaker::Host::CommandFailure do
        run_cron_on default, :list, default['user']
      end
    end

    step "#run_cron_on fails when removing cron jobs for an unknown user" do
      assert_raises Beaker::Host::CommandFailure do
        run_cron_on default, :remove, "nonexistentuser"
      end
    end

    step "#run_cron_on can list cron jobs for a user on all hosts when given a host array" do
      hosts.each do |host|
        # this basically requires us to add a cron entry to make this work
        run_cron_on host, :add, host['user'], "* * * * * /bin/ls >/dev/null"
      end

      results = run_cron_on hosts, :list, default['user']
      results.each do |result|
        assert_match %r{/bin/ls}, result.stdout
      end
    end

    step "#run_cron_on can add cron jobs for a user on all hosts when given a host array" do
      run_cron_on hosts, :add, default['user'], "* * * * * /bin/ls >/dev/null"

      results = run_cron_on hosts, :list, default['user']
      results.each do |result|
        assert_match %r{/bin/ls}, result.stdout
      end
    end

    step "#run_cron_on can remove cron jobs for a user on all hosts when given a host array" do
      run_cron_on hosts, :add, default['user'], "* * * * * /bin/ls >/dev/null"
      run_cron_on hosts, :remove, default['user']

      hosts.each do |host|
        assert_raises Beaker::Host::CommandFailure do
          results = run_cron_on host, :list, host['user']
        end
      end
    end
  end

  confine_block :except, :platform => /windows|solaris/ do

    step "#run_cron_on CURRENTLY does nothing and returns `nil` when an unknown command is provided" do
      # NOTE: would have expected this to raise Beaker::Host::CommandFailure instead

      assert_nil run_cron_on default, :nonexistent_action, default['user']
    end

    step "#run_cron_on fails when listing cron jobs for an unknown user" do
      assert_raises Beaker::Host::CommandFailure do
        run_cron_on default, :list, "nonexistentuser"
      end
    end

    step "#run_cron_on fails when listing cron jobs for a user with no cron entries" do
      assert_raises Beaker::Host::CommandFailure do
        run_cron_on default, :list, default['user']
      end
    end

    step "#run_cron_on returns a list of cron jobs for a user with cron entries" do
      # this basically requires us to add a cron entry to make this work
      run_cron_on default, :add, default['user'], "* * * * * /bin/ls >/dev/null"
      result = run_cron_on default, :list, default['user']
      assert_equal 0, result.exit_code
      assert_match %r{/bin/ls}, result.stdout
    end

    step "#run_cron_on fails when adding cron jobs for an unknown user" do
      assert_raises Beaker::Host::CommandFailure do
        run_cron_on default, :add, "nonexistentuser", %Q{* * * * * /bin/echo "hello" >/dev/null}
      end
    end

    step "#run_cron_on fails when attempting to add a bad cron entry" do
      assert_raises Beaker::Host::CommandFailure do
        run_cron_on default, :add, default['user'], "* * * * /bin/ls >/dev/null"
      end
    end

    step "#run_cron_on can add a cron job for a user on a host" do
      run_cron_on default, :add, default['user'], %Q{* * * * * /bin/echo "hello" >/dev/null}
      result = run_cron_on default, :list, default['user']
      assert_equal 0, result.exit_code
      assert_match %r{/bin/echo}, result.stdout
    end

    step "#run_cron_on CURRENTLY replaces all of user's cron jobs with any newly added jobs" do
      # NOTE: would have expected this to append new entries, or manage them as puppet manages
      #       cron entries.  See also: https://github.com/puppetlabs/beaker/pull/937#discussion_r38338494

      1.upto(3) do |job_number|
        run_cron_on default, :add, default['user'], %Q{* * * * * /bin/echo "job :#{job_number}:" >/dev/null}
      end

      result = run_cron_on default, :list, default['user']

      assert_no_match %r{job :1:}, result.stdout
      assert_no_match %r{job :2:}, result.stdout
      assert_match %r{job :3:}, result.stdout
    end

    step "#run_cron_on :remove CURRENTLY removes all cron jobs for a user on a host" do
      # NOTE: would have expected a more granular approach to removing cron jobs
      #       for a user on a host.  This should otherwise be better documented.

      run_cron_on default, :add, default['user'], %Q{* * * * * /bin/echo "quality: job 1" >/dev/null}
      result = run_cron_on default, :list, default['user']
      assert_match %r{quality: job 1}, result.stdout

      run_cron_on default, :remove, default['user']

      assert_raises Beaker::Host::CommandFailure do
        run_cron_on default, :list, default['user']
      end
    end

    step "#run_cron_on fails when removing cron jobs for an unknown user" do
      assert_raises Beaker::Host::CommandFailure do
        run_cron_on default, :remove, "nonexistentuser"
      end
    end

    step "#run_cron_on can list cron jobs for a user on all hosts when given a host array" do
      hosts.each do |host|
        # this basically requires us to add a cron entry to make this work
        run_cron_on host, :add, host['user'], "* * * * * /bin/ls >/dev/null"
      end

      results = run_cron_on hosts, :list, default['user']
      results.each do |result|
        assert_match %r{/bin/ls}, result.stdout
      end
    end

    step "#run_cron_on can add cron jobs for a user on all hosts when given a host array" do
      run_cron_on hosts, :add, default['user'], "* * * * * /bin/ls >/dev/null"

      results = run_cron_on hosts, :list, default['user']
      results.each do |result|
        assert_match %r{/bin/ls}, result.stdout
      end
    end

    step "#run_cron_on can remove cron jobs for a user on all hosts when given a host array" do
      run_cron_on hosts, :add, default['user'], "* * * * * /bin/ls >/dev/null"
      run_cron_on hosts, :remove, default['user']

      hosts.each do |host|
        assert_raises Beaker::Host::CommandFailure do
          results = run_cron_on host, :list, host['user']
        end
      end
    end
  end

  # NOTE: there does not seem to be a reliable way to confine to cygwin hosts.
  confine_block :to, :platform => /windows/ do

    step "#create_tmpdir_on CURRENTLY fails when attempting to chown the created tempdir to the host user + group, on windows platforms" do
      # NOTE: would have expected this to work.
      # TODO: fix via https://tickets.puppetlabs.com/browse/BKR-496

      assert_raises Beaker::Host::CommandFailure do
        tmpdir = create_tmpdir_on default
      end
    end
  end

  confine_block :except, :platform => /windows/ do

    step "#create_tmpdir_on chowns the created tempdir to the host user + group" do
      tmpdir = create_tmpdir_on default
      listing = on(default, "ls -al #{tmpdir}").stdout
      tmpdir_ls = listing.split("\n").grep %r{\s+\./?\s*$}
      assert_equal 1, tmpdir_ls.size
      perms, inodes, owner, group, *rest = tmpdir_ls.first.split(/\s+/)
      assert_equal default['user'], owner
      assert_equal default['user'], group
    end

    step "#create_tmpdir_on returns a temporary directory on the remote system" do
      tmpdir = create_tmpdir_on default
      assert_match %r{/}, tmpdir
      assert_equal 0, on(default, "touch #{tmpdir}/testfile").exit_code
    end

    step "#create_tmpdir_on uses the specified path prefix when provided" do
      tmpdir = create_tmpdir_on(default, "mypathprefix")
      assert_match %r{/mypathprefix}, tmpdir
      assert_equal 0, on(default, "touch #{tmpdir}/testfile").exit_code
    end

    step "#create_tmpdir_on fails if a non-existent user is specified" do
      assert_raises Beaker::Host::CommandFailure do
        tmpdir = create_tmpdir_on default, '', "fakeuser"
      end
    end

    step "#create_tmpdir_on operates on all hosts if given a hosts array" do
      tmpdirs = create_tmpdir_on hosts
      hosts.zip(tmpdirs).each do |(host, tmpdir)|
        assert_match %r{/}, tmpdir
        assert_equal 0, on(host, "touch #{tmpdir}/testfile").exit_code
      end
    end

    step "#create_tmpdir_on CURRENTLY fails with a RuntimeError if the host platform is not supported" do
      # TODO - identify a platform which does not support tmpdir
      #
      # assert_raises RuntimeError do
      #   create_tmpdir_on default
      # end
    end
  end

  step "#echo_on echoes the supplied string on the remote host" do
    output = echo_on(default, "contents")
    assert_equal output, "contents"
  end

  step "#echo_on echoes the supplied string on all hosts when given a hosts array" do
    results = echo_on(hosts, "contents")
    assert_equal ["contents"] * hosts.size, results
  end
end
