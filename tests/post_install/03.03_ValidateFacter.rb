# Validate Facter Install

binpath="/opt/puppet/bin"

test_name="Validate Facter Install"
# Validate correct facter bin path on each host
hosts.each do |host|
  BeginTest.new(host, test_name)
  runner = RemoteExec.new(host)
  result = runner.do_remote("#{binpath}/facter --version")
  @fail_flag+=result.exit_code
  result.log(test_name)
end
