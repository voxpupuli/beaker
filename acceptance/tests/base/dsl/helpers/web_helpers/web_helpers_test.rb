require 'helpers/test_helper'
require 'webrick'
require 'webrick/https'

test_name 'dsl::helpers::web_helpers #link_exists?' do

  http_cmd = "ruby -rwebrick -e'WEBrick::HTTPServer.new(:Port => 80, :DocumentRoot => Dir.pwd).start' > /tmp/mylogfile 2>&1 &"
  host = hosts[0]
  on(host, http_cmd)
  on(host, 'mkdir tmp')
  create_remote_file(host, 'tmp/test.txt', 'test')

  dst_dir = 'web_helpers/'

  step '#port_open_within? can tell if a port is open' do
    assert port_open_within?(host,80,1)
  end

  step '#link_exists? can tell if a basic link exists' do
    assert link_exists?("http://#{host}")
  end

  step '#link_exists? can tell if a basic link does not exist' do
    assert !link_exists?("http://#{host}/test")
  end

  step '#link_exists? can use an ssl link' do
    host = hosts[0]

    cert_name = [
        %w[CN localhost],
    ]

    http_cmd = "ruby -rwebrick/https -e'WEBrick::HTTPServer.new(:SSLEnable => true, :SSLCertName => #{cert_name}, :Port => 4430,
:DocumentRoot => Dir.pwd).start' > /tmp/mylogfile 2>&1 &"

    sleep(2)
    on(host, http_cmd)
    assert link_exists?("https://#{host}:4430")
  end

  step '#fetch_http_dir can fetch a dir' do
    assert_equal "#{dst_dir}tmp", fetch_http_dir("http://#{host}/tmp", dst_dir)
  end

  step '#fetch_http_dir will raise an error if unable fetch a dir' do
    begin
      fetch_http_dir("http://#{host}/tmps", dst_dir)
    rescue RuntimeError => e
      assert_match /Failed to fetch_remote_dir.*/, e.message, "#fetch_http_dir raised an unexpected RuntimeError"
    end
  end

  step '#fetch_http_file can fetch a file' do
    assert_equal "#{dst_dir}test.txt", fetch_http_file("http://#{host}/tmp", "test.txt", dst_dir)
  end

  step '#fetch_http_file will raise an error if unable to fetch a file' do
    begin
      fetch_http_file("http://#{host}/tmp", "test2.txt", dst_dir)
    rescue RuntimeError => e
      assert_match /Failed to fetch_remote_file.*/, e.message, "#fetch_http_file raised an unexpected RuntimeError"
    end
  end

end