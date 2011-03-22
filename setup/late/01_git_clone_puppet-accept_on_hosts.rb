step "Git clone puppet-acceptance on all hosts"
on hosts, "cd /opt/puppet-git-repos/puppet-acceptance && git pull || cd /opt/puppet-git-repos && git clone git://github.com/puppetlabs/puppet-acceptance.git"
