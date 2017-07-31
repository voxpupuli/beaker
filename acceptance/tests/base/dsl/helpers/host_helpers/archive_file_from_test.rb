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

  step "fails archive_file_from when from_path is non-existant" do
    filepath = "foo-filepath-should-not-exist"
    assert_raises IOError do
      archive_file_from(default, filepath)
    end
  end

  step "archive is copied to local <archiveroot>/<hostname>/<filepath> directory" do
    # Create a remote file to archive
    filepath = default.tmpfile('archive-file-test')
    create_remote_file(default, filepath, 'number of the beast')
    assert_equal(false, Dir.exists?(filepath))

    # Test that the file is copied locally to <archiveroot>/<hostname>/<filepath>
    Dir.mktmpdir do |tmpdir|
      tar_path = File.join(tmpdir, default, filepath + '.tgz')
      archive_file_from(default, filepath, {}, tmpdir, tar_path)
      assert(File.exists?(tar_path))
      expected_path = File.join(tmpdir, default)

      tgz = Zlib::GzipReader.new(File.open(tar_path, 'rb'))
      Minitar.unpack(tgz, expected_path)
      assert_equal('number of the beast', File.read(expected_path + '/' + filepath).strip)
    end
  end
end
