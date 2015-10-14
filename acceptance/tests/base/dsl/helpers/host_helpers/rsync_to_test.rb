require "helpers/test_helper"

test_name "dsl::helpers::host_helpers #rsync_to" do

  confine_block :to, :platform => /^solaris.*10/ do

    step "#rsync_to CURRENTLY will fail without error, but not copy the requested file, on #{default['platform']} due to lack of installed rsync" do

      # NOTE: this should be documented
      # FIXME: This is also true for CentOS/EL-*, but package removal appears
      #        to not be working properly, so we cannot get test isolation
      #        to test this as if the system is pristine.
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

  confine_block :to, :platform => /^centos|el-\d|fedora/ do
    step "installing `rsync` on #{default['platform']} for all later test steps" do
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

  confine_block :except, :platform => /windows|solaris.*10/ do

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
