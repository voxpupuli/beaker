$LOAD_PATH << File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', '..', '..', 'lib'))

# require 'helpers/test_helper'

test_name 'dsl::helpers::web_helpers #link_exists?' do

  step '#link_exists? can tell if a basic link exists' do
    host = hosts[0]

    python_check_result = on(host, 'python --version')
    assert python_check_result.exit_code == 0
    on(host, 'nohup python -m SimpleHTTPServer 80 > pants.log < /dev/null 2>&1 &')
    sleep(1) # needs a sleep to setup the HTTP server, otherwise not ready for request

    # ruby_check_result = on(host, 'ruby --version')
    # assert ruby_check_result.exit_code == 0
    # host_ruby_version = ruby_check_result.stdout.split()[1]
    # puts "ruby version: '#{host_ruby_version}'"
    #
    # if version_is_less(host_ruby_version, '1.9.2')
    #   http_cmd = "ruby -rwebrick -e'WEBrick::HTTPServer.new(:Port => 80, :DocumentRoot => Dir.pwd).start'"
    # else
    #   http_cmd = 'ruby -run -ehttpd . -p80'
    # end
    # http_cmd << ' &'
    # puts "normal ssh dir: '#{on(host, 'pwd').stdout}'"
    # on(host, http_cmd)

    puts "trying assert!"
    assert link_exists?("http://#{host}")
    puts "done trying assert"
  end

#   step '#link_exists? can use an ssl link' do
#     host = hosts[0]
#     ssl_server_file = <<END
# import BaseHTTPServer, SimpleHTTPServer
# import ssl
#
# httpd = BaseHTTPServer.HTTPServer(('localhost', 443), SimpleHTTPServer.SimpleHTTPRequestHandler)
# httpd.socket = ssl.wrap_socket (httpd.socket, certfile='path/to/localhost.pem', server_side=True)
# httpd.serve_forever()
# END
#
#     file_dir = create_tmpdir_on(host)
#     file_path = File.join(file_dir, 'ssl_server.py')
#     puts "file path: '#{file_path}'"
#     create_remote_file(host, file_path, ssl_server_file)
#     on(host, "nohup python #{file_path} > ssl.log < /dev/null 2>&1 &")
#     sleep(1)
#
#     assert link_exists?("https://#{host}")
#   end



end