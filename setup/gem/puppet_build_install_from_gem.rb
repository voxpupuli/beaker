test_name "Install Puppet from GEM"

SourcePath  = "/opt/puppet-git-repos"
GitHub      = 'git://github.com/puppetlabs'
IsURI       = %r{^[^:]+://}
IsGitHubURI = %r{(https://github.com/[^/]+/[^/]+)(?:/tree/(.*))$}
package     = 'puppet'

step "Parse Opts"
if match = IsGitHubURI.match(options[:puppet]) then
  PuppetRepo = match[1] + '.git'
  PuppetRev  = match[2] || 'origin/master'
elsif options[:puppet] =~ IsURI then
  repo, rev = options[:puppet].split('#', 2)
  PuppetRepo = repo
  PuppetRev  = rev || 'HEAD'
else
  PuppetRepo = "#{GitHub}/puppet.git"
  PuppetRev  = options[:puppet]
end

def clone_repo(host, package, repo, revision)
  step "Clean and create #{SourcePath}"
  on host, "rm -rf #{SourcePath} && mkdir -vp #{SourcePath}"
  step "Clone #{repo}"
  on host, "cd #{SourcePath} && git clone #{repo}"

  step "Check out the revision #{revision}"
  on host, "cd #{SourcePath}/#{package} && git checkout #{revision}"

  step "grab git repo version"
  version = {}
  on host, "cd /opt/puppet-git-repos/#{package} && git describe" do
    version = stdout.chomp
  end
  config[:version] = version
end

def install_support_gems(host)
  step "Install rake and rspec gems"
  on host, "gem install rake rspec"
end

def install_puppet_gem(host, package, gem_version)
  step "Build Puppet Gem"
  on host, "cd /opt/puppet-git-repos/#{package} && rake puppetpackages"
  step "Install Puppet Gem"
  on host, "cd /opt/puppet-git-repos/#{package}/pkg && gem install puppet-#{gem_version}.gem"
end

# Clone repo on each host
hosts.each do |host|
  clone_repo host, package, PuppetRepo, PuppetRev
end

# Determine GEM version and run install or fail
# Puppet version might be 2.6.9rc1-3-gc974653 while gem will be 2.6.9
gem_version=''
if config[:version] =~ /^(\d+\.\d+\.\d+)\w.*/
  gem_version = $1
  hosts.each do |host|
    install_support_gems host
    install_puppet_gem host, package, gem_version
  end
else
  fail_test "Not able to determine puppet gem version from #{config[:version]}!"
end
