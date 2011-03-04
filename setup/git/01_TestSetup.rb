test_name "Install puppet and facter on target machines..."

SourcePath = "/opt/puppet-git-repos"
GitHub     = 'git://github.com/puppetlabs'
IsURI      = %r{^[^:]+://}
 
step "Parse Opts"
if options[:puppet] =~ IsURI then
  repo, rev = options[:puppet].split('#', 2)
  PuppetRepo = repo
  PuppetRev  = rev || 'HEAD'
else
  PuppetRepo = "#{GitHub}/puppet.git"
  PuppetRev  = options[:puppet]
end

if options[:facter] =~ IsURI then
  repo, rev = options[:facter].split('#', 2)
  FacterRepo = repo
  FacterRev  = rev || 'HEAD'
else
  FacterRepo = "#{GitHub}/facter.git"
  FacterRev  = options[:facter]
end

hosts.each do |host|
  step "Clean and create #{SourcePath}"
  on host, "rm -rf #{SourcePath} && mkdir -vp #{SourcePath}"

  step "Clone #{FacterRepo}"
  on host, "cd #{SourcePath} && git clone #{FacterRepo}"

  step "Check out the revision #{FacterRev}"
  on host, "cd #{SourcePath}/facter && git checkout -b #{FacterRev}"

  step "Install facter on the system"
  on host, "cd #{SourcePath}/facter && ruby ./install.rb"

  step "Clone #{PuppetRepo}"
  on host, "cd #{SourcePath} && git clone #{PuppetRepo}"

  step "Check out the revision #{PuppetRev}"
  on host, "cd #{SourcePath}/puppet && git checkout -b #{PuppetRev}"

  step "Install puppet on the system"
  on host, "cd #{SourcePath}/puppet && ruby ./install.rb"

  step "Create required users and groups"
  on host, "getent group puppet || groupadd puppet"
  on host, "getent passwd puppet || useradd puppet -g puppet -G puppet"

  step "REVISIT: Work around bug #5794 not creating reports as required"
  on host, "mkdir -vp /tmp/reports && chown -v puppet:puppet /tmp/reports"
end
