require "helpers/test_helper"

test_name "dsl::helpers::host_helpers #archive_file_from" do

  step "archiveroot parameter defaults to `archive/sut-files`" do
    # Create a remote file to archive
    filepath = default.tmpfile('archive-file-test')
    create_remote_file(default, filepath, 'contents ignored')

    # Prepare cleanup so we don't pollute the local filesystem
    teardown do
      FileUtils.rm_rf('archive') if Dir.exists?('archive')
    end

    # Test that the archiveroot default directory is created
    assert_equal(false, Dir.exists?('archive'))
    assert_equal(false, Dir.exists?('archive/sut-files'))
    archive_file_from(default, filepath)
    assert_equal(true, Dir.exists?('archive/sut-files'))
  end

  step "file is copied to local <archiveroot>/<host name> directory" do
    # Create a remote file to archive
    filepath = default.tmpfile('archive-file-test')
    create_remote_file(default, filepath, 'number of the beast')

    # Test that the file is copied locally to <archiveroot>/<hostname>/<filepath>
    Dir.mktmpdir do |tmpdir|
      archive_file_from(default, filepath, {}, tmpdir)
      expected_path = File.join(tmpdir, default, filepath)
      assert(File.exists?(expected_path))
      assert_equal('number of the beast', File.read(expected_path).strip)
    end
  end
end
