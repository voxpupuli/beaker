step "Validate Sign Cert"

# This step should not be req'd for PE edition -- agents req certs during install
# AGENT(s) intiate Cert Signing with PMASTER
#
# Note that this passes an ampersand as a final argument in an attempt
# to get the agent to run in the background.  Not sure if this will
# work now.
#
# run_agent_on agents,"--no-daemonize --verbose --onetime --test --waitforcert 10 &"

step "Puppet Master clean and generate agent certs"
on master,"puppet cert --clean #{agents.join(' ')}"
on master,"puppet cert --generate #{agents.join(' ')}"
