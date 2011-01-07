step "Validate Sign Cert"

# This step should not be req'd for PE edition -- agents req certs during install
# AGENT(s) intiate Cert Signing with PMASTER
#
# run_agent_on agents,"--no-daemonize --verbose --onetime --test --waitforcert 10 &"

step "Puppet Master clean and generate agent certs"
on master,"puppet cert --clean #{agents.join(' ')}"
on master,"puppet cert --generate #{agents.join(' ')}"
