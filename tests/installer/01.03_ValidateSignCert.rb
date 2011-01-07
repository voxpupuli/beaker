step "Validate Sign Cert"

# This step should not be req'd for PE edition -- agents req certs during install
# AGENT(s) intiate Cert Signing with PMASTER
#
# run_agent_on agents,"--no-daemonize --verbose --onetime --test --waitforcert 10 &"

step "Puppet Master Sign Requested Agent Certs"
on master,"puppet cert --sign #{agents.join(' ')}"
