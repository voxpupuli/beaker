# Test Template

# Very simple test case

test_name="Perform same action on each host"
# SCP install file to each host
hosts.each do |host|
  BeginTest.new(host, test_name)
  runner = RemoteExec.new(host)
  result = runner.do_remote("uname")
  @fail_flag+=result.exit_code
  result.log(test_name)
end

test_name="Perform specific action based on host's role"
# Parse for 'role' and take action accordingly
hosts.each do|host|
  @config[host]['roles'].each do|role|
    if /master/ =~ role then             # The host is puppet master
      BeginTest.new(host, test_name)
      runner = RemoteExec.new(host)
      result = runner.do_remote("puppet master specific command")
      @fail_flag+=result.exit_code
      result.log(test_name)
    elsif /agent/ =~ role then           # The host is puppet agent
      BeginTest.new(host, test_name)
      runner = RemoteExec.new(host)
      result = runner.do_remote("puppet agent specific command")
      @fail_flag+=result.exit_code
      result.log(test_name)
    elsif /dashboard/ =~ role then       # If the host will run dashboard
      BeginTest.new(host, test_name)
      runner = RemoteExec.new(host)
      result = runner.do_remote("puppet dashboard specific command")
      @fail_flag+=result.exit_code
      result.log(test_name)
    end
  end
end
