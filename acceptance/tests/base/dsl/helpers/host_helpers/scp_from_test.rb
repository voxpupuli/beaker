require "helpers/test_helper"

test_name "dsl::helpers::host_helpers #scp_from" do
  if test_scp_error_on_close?
    step "#scp_from fails if the local path cannot be found" do
      remote_tmpdir = default.tmpdir()
      remote_filename, _contents = create_remote_file_from_fixture("simple_text_file", default, remote_tmpdir, "testfile.txt")

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
      remote_tmpdir = default.tmpdir()
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
      remote_tmpdir = default.tmpdir()
      remote_filename = File.join(remote_tmpdir, "testfile.txt")
      on hosts, "mkdir -p #{remote_tmpdir}"
      on hosts, %Q{echo "${RANDOM}:${RANDOM}:${RANDOM}" > #{remote_filename}}

      scp_from hosts, remote_filename, local_dir
      remote_contents = on(hosts.last, "cat #{remote_filename}").stdout

      local_filename = File.join(local_dir, "testfile.txt")
      local_contents = File.read(local_filename)
      assert_equal remote_contents, local_contents
    end
  end
end
