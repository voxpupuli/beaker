# Agents certs will remain waiting for signing on master until this step
#
step "PE: Puppet Master Sign all Requested Agent Certs"
on master,"puppet cert --sign #{agents.join(' ')}"
