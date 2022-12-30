require "helpers/test_helper"

test_name "dsl::helpers::host_helpers #scp_to" do
  step "#scp_to fails if the local file cannot be found" do
    remote_tmpdir = default.tmpdir()
    assert_raises IOError do
      scp_to default, "/non/existent/file.txt", remote_tmpdir
    end
  end

  if test_scp_error_on_close?
    step "#scp_to fails if the remote path cannot be found" do
      Dir.mktmpdir do |local_dir|
        local_filename, _contents = create_local_file_from_fixture("simple_text_file", local_dir, "testfile.txt")

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
      remote_tmpdir = default.tmpdir()

      scp_to default, local_filename, remote_tmpdir

      remote_filename = File.join(remote_tmpdir, "testfile.txt")
      remote_contents = on(default, "cat #{remote_filename}").stdout
      assert_equal contents, remote_contents
    end
  end

  step "#scp_to creates the file on all remote systems when a host array is provided" do
    Dir.mktmpdir do |local_dir|
      local_filename, contents = create_local_file_from_fixture("simple_text_file", local_dir, "testfile.txt")

      remote_tmpdir = default.tmpdir()
      on hosts, "mkdir -p #{remote_tmpdir}"
      remote_filename = File.join(remote_tmpdir, "testfile.txt")

      scp_to hosts, local_filename, remote_tmpdir

      hosts.each do |host|
        remote_contents = on(host, "cat #{remote_filename}").stdout
        assert_equal contents, remote_contents
      end
    end
  end

end
