# JJM Set the base directory where puppet, facter, etc are checked out.
: ${FACTER_PUPPET_BASE:=/opt/puppetlabs}
# JJM Set the RUBYLIB
export RUBYLIB="${FACTER_PUPPET_BASE}/puppet/lib:${FACTER_PUPPET_BASE}/facter/lib:${FACTER_PUPPET_BASE}/puppet-scaffold/lib:${FACTER_PUPPET_BASE}/puppet-module-tool/lib:/Users/jeff/customization/lib/ruby"
# JJM Set the PATH
export PATH="${FACTER_PUPPET_BASE}/puppet/sbin:${FACTER_PUPPET_BASE}/puppet/bin:${FACTER_PUPPET_BASE}/facter/bin:${FACTER_PUPPET_BASE}/puppet-scaffold/bin:${PATH}"
