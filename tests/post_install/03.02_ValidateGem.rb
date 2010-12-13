# Validate Gem Install

binpath="/opt/puppet/bin"

test_name="Validate Gem Install"
# Validate correct gem bin path on each host
hosts.each do |host|
  BeginTest.new(host, test_name)
  runner = RemoteExec.new(host)
  result = runner.do_remote("#{binpath}/gem --version")
  @fail_flag+=result.exit_code
  result.log(test_name)
end
