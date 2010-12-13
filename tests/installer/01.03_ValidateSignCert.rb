# Validate Cert Signing

test_name="Validate Sign Cert"

# This step should not be req'd for PE edition -- agents req certs during install
# AGENT(s) intiate Cert Signing with PMASTER
#agents.each do |host|
#  BeginTest.new(host, test_name)
#  runner = RemoteExec.new(host)
#  result = runner.do_remote("puppet agent --no-daemonize --verbose --onetime --test --waitforcert 10 &")
#  @fail_flag+=result.exit_code
#  result.log(test_name)
#end

# Sign Agent Certs from PMASTER
test_name="Puppet Master Sign Requested Agent Certs"
BeginTest.new(master, test_name)
runner = RemoteExec.new(master)
result = runner.do_remote("puppet cert --sign #{agents.join(' ')}")
@fail_flag+=result.exit_code
result.log(test_name)
