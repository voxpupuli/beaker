require "helpers/test_helper"

test_name "dsl::helpers::host_helpers #backup_the_file" do
  step "#backup_the_file CURRENTLY will return nil if the file does not exist in the source directory" do
    # NOTE: would expect this to fail with Beaker::Host::CommandFailure
    remote_source = default.tmpdir()
    remote_destination = default.tmpdir()
    result = backup_the_file default, remote_source, remote_destination
    assert_nil result
  end

  step "#backup_the_file will fail if the destination directory does not exist" do
    remote_source = default.tmpdir()
    create_remote_file_from_fixture("simple_text_file", default, remote_source, "puppet.conf")

    assert_raises Beaker::Host::CommandFailure do
      backup_the_file default, remote_source, "/non/existent/"
    end
  end

  step "#backup_the_file copies `puppet.conf` from the source to the destination directory" do
    remote_source = default.tmpdir()
    _remote_filename, contents = create_remote_file_from_fixture("simple_text_file", default, remote_source, "puppet.conf")

    remote_destination = default.tmpdir()
    remote_destination_filename = File.join(remote_destination, "puppet.conf.bak")

    result = backup_the_file default, remote_source, remote_destination

    assert_equal remote_destination_filename, result
    remote_contents = on(default, "cat #{remote_destination_filename}").stdout
    assert_equal contents, remote_contents
  end

  step "#backup_the_file copies a named file from the source to the destination directory" do
    remote_source = default.tmpdir()
    _remote_filename, contents = create_remote_file_from_fixture("simple_text_file", default, remote_source, "testfile.txt")

    remote_destination = default.tmpdir()
    remote_destination_filename = File.join(remote_destination, "testfile.txt.bak")

    result = backup_the_file default, remote_source, remote_destination, "testfile.txt"

    assert_equal remote_destination_filename, result
    remote_contents = on(default, "cat #{remote_destination_filename}").stdout
    assert_equal contents, remote_contents
  end

  step "#backup_the_file CURRENTLY will fail if given a hosts array" do
    remote_source = default.tmpdir()
    create_remote_file_from_fixture("simple_text_file", default, remote_source, "testfile.txt")
    remote_destination = default.tmpdir()

    assert_raises NoMethodError do
      backup_the_file hosts, remote_source, remote_destination
    end
  end
end
