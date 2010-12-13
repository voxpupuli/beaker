# Validate Ruby Install

binpath="/opt/puppet/bin"

test_name="Validate Ruby Install"
# Validate correct ruby bin path on each host
hosts.each do|host|
  BeginTest.new(host, test_name)
  runner = RemoteExec.new(host)
  result = runner.do_remote("#{binpath}/ruby --version")
  @fail_flag+=result.exit_code
  result.log(test_name)
end
