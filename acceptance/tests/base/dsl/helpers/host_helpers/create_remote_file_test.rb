require "helpers/test_helper"

test_name "dsl::helpers::host_helpers #create_remote_file" do

  confine_block :to, :platform => /^centos|el-\d|fedora/ do
    step "installing `rsync` on #{default['platform']} for all later test steps" do
      hosts.each do |host|
        install_package host, "rsync"
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
  confine_block :to, :platform => /windows/ do

    # NOTE: rsync methods are not working currently on windows platforms

    step "#create_remote_file CURRENTLY fails on #{default['platform']}, using rsync" do
      remote_tmpdir = tmpdir_on default
      remote_filename = File.join(remote_tmpdir, "testfile.txt")
      contents = fixture_contents("simple_text_file")

      create_remote_file default, remote_filename, contents, { :protocol => "rsync" }

      assert_raises Beaker::Host::CommandFailure do
        remote_contents = on(default, "cat #{remote_filename}").stdout
      end
    end
  end

  confine_block :except, :platform => /windows/ do

    step "#create_remote_file creates a remote file with the specified contents, using rsync" do
      remote_tmpdir = tmpdir_on default
      remote_filename = File.join(remote_tmpdir, "testfile.txt")
      contents = fixture_contents("simple_text_file")

      result = create_remote_file default, remote_filename, contents, { :protocol => "rsync" }

      fails_intermittently("https://tickets.puppetlabs.com/browse/BKR-612",
        "default" => default,
        "remote_tmpdir" => remote_tmpdir,
        "remote_filename" => remote_filename,
        "contents" => contents,
        "result" => result
        ) do
          remote_contents = on(default, "cat #{remote_filename}").stdout
          assert_equal contents, remote_contents
      end
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

  step "#create_remote_file creates remote files on all remote hosts, when given an array" do
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

  step "#create_remote_file creates remote files on all remote hosts, when given an array, using scp" do
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
  confine_block :to, :platform => /windows/ do

    # NOTE: rsync methods are not working currently on windows
    #       platforms. Would expect this to be documented better.

    step "#create_remote_file creates remote files on all remote hosts, when given an array, using rsync" do
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

  confine_block :except, :platform => /windows|fedora/ do

    step "#create_remote_file creates remote files on all remote hosts, when given an array, using rsync" do
      remote_tmpdir = tmpdir_on default

      # NOTE: we do not do this step in the non-hosts-array version of the test, not sure why
      on hosts, "mkdir -p #{remote_tmpdir}"

      remote_filename = File.join(remote_tmpdir, "testfile.txt")
      contents = fixture_contents("simple_text_file")

      result = create_remote_file hosts, remote_filename, contents, { :protocol => 'rsync' }

      hosts.each do |host|
        fails_intermittently("https://tickets.puppetlabs.com/browse/BKR-612",
          "host" => host,
          "remote_tmpdir" => remote_tmpdir,
          "remote_filename" => remote_filename,
          "contents" => contents,
          "result" => result
          ) do
          remote_contents = on(host, "cat #{remote_filename}").stdout
          assert_equal contents, remote_contents
        end
      end
    end
  end

  confine_block :to, :platform => /centos|el-\d|fedora/ do

    step "uninstall rsync package on #{default['platform']} for later test runs" do
      # NOTE: this is basically a #teardown section for test isolation
      #       Could we reorganize tests into different files to make this
      #       clearer?

      hosts.each do |host|
        on host, "yum -y remove rsync"
      end
    end
  end
end
