require 'helpers/test_helper'
require 'webrick'
require 'webrick/https'

confine :except, :platform => %w(windows solaris-11 osx)

test_name 'dsl::helpers::web_helpers #link_exists?' do
  cert_name = [
      %w[CN localhost],
  ]
  http_cmd = "ruby -rwebrick -e'WEBrick::HTTPServer.new(:Port => 80, :DocumentRoot => \"/tmp\").start' > /tmp/mylogfile 2>&1 &"
  https_cmd = "ruby -rwebrick/https -e'WEBrick::HTTPServer.new(:SSLEnable => true, :SSLCertName => #{cert_name}, :Port => 4430,:DocumentRoot => \"/tmp\").start' > /tmp/mylogfile 2>&1 &"
  on(default, http_cmd)
  on(default, https_cmd)
  dir = default.tmpdir('test_dir')
  file = default.tmpfile('test_file')
  dir.slice! "/tmp"
  file.slice! "/tmp"
  dst_dir = 'web_helpers'

  step '#port_open_within? can tell if a port is open' do
    assert port_open_within?(default,80)
  end

  step '#link_exists? can tell if a basic link exists' do
    assert link_exists?("http://#{default}")
  end

  step '#link_exists? can tell if a basic link does not exist' do
    assert !link_exists?("http://#{default}/test")
  end

  step '#link_exists? can use an ssl link' do
    assert link_exists?("https://#{default}:4430")
  end

  step '#fetch_http_dir can fetch a dir' do
    assert_equal "#{dst_dir}#{dir}", fetch_http_dir("http://#{default}/#{dir}", dst_dir)
  end

  step '#fetch_http_dir will raise an error if unable fetch a dir' do
    exception = assert_raises(RuntimeError) { fetch_http_dir("http://#{default}/tmps", dst_dir) }
    assert_match /Failed to fetch_remote_dir.*/, exception.message, "#fetch_http_dir raised an unexpected RuntimeError"
  end

  step '#fetch_http_file can fetch a file' do
    assert_equal "#{dst_dir}#{file}", fetch_http_file("http://#{default}", file, dst_dir)
  end

  step '#fetch_http_file will raise an error if unable to fetch a file' do
    exception = assert_raises(RuntimeError) { fetch_http_file("http://#{default}", "test2.txt", dst_dir) }
    assert_match /Failed to fetch_remote_file.*/, exception.message, "#fetch_http_dir raised an unexpected RuntimeError"
  end

end