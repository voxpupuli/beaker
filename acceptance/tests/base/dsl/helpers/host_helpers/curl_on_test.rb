require "helpers/test_helper"

# construct an appropriate local file URL for curl testing
def host_local_url(host, path)
  if host.is_cygwin?
    "file://#{path.gsub('/', '\\\\\\\\')}"
  else
    "file://#{path}"
  end
end

test_name "dsl::helpers::host_helpers #curl_on" do
  step "#curl_on fails if the URL in question cannot be reached" do
    assert Beaker::Host::CommandFailure do
      curl_on default, "file:///non/existent.html"
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
end
