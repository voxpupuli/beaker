$LOAD_PATH << File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', '..', '..', 'lib'))

# require 'helpers/test_helper'

test_name 'dsl::helpers::web_helpers #link_exists?' do

  step '#link_exists? uses SSL if it\'s used in the link' do
    assert hosts.length > 0
    host = hosts[0]
    file_dir = create_tmpdir_on(host)
    file_path = File.join(file_dir, 'link_exists_test01.txt')
    puts "file path: '#{file_path}'"
    create_remote_file(host, file_path, 'dooot dooot')

    # python_check_result = on(host, 'python --version')
    # assert python_check_result.exit_code == 0
    # on(host, 'python -m SimpleHTTPServer &')

    ruby_check_result = on(host, 'ruby --version')
    assert ruby_check_result.exit_code == 0
    host_ruby_version = ruby_check_result.stdout.split()[1]
    puts "ruby version: '#{host_ruby_version}'"

    if version_is_less(host_ruby_version, '1.9.2')
      http_cmd = "ruby -rwebrick -e'WEBrick::HTTPServer.new(:Port => 8000, :DocumentRoot => Dir.pwd).start'"
    else
      http_cmd = 'ruby -run -ehttpd . -p8000'
    end
    http_cmd << ' &'
    puts "normal ssh dir: '#{on(host, 'pwd').stdout}'"
    on(host, http_cmd)
  end

end