test_name "Install puppet and facter on target machines..."

SourcePath  = "/opt/puppet-git-repos"
GitHub      = 'git://github.com/puppetlabs'
IsURI       = %r{^[^:]+://|^git@github.com:}
IsGitHubURI = %r{(https://github.com/[^/]+/[^/]+)(?:/tree/(.*))$}

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

if match = IsGitHubURI.match(options[:facter]) then
  FacterRepo = match[1] + '.git'
  FacterRev  = match[2] || 'origin/master'
elsif options[:facter] =~ IsURI then
  repo, rev = options[:facter].split('#', 2)
  FacterRepo = repo
  FacterRev  = rev || 'HEAD'
else
  FacterRepo = "#{GitHub}/facter.git"
  FacterRev  = options[:facter]
end

def install_from_git(host, package, repo, revision)
  step "Clone #{repo}"
  on host, "cd #{SourcePath} && git clone #{repo} #{package}"

  step "Check out the revision #{revision}"
  on host, "cd #{SourcePath}/#{package} && git checkout #{revision}"

  step "Install #{package} on the system"
  on host, "cd #{SourcePath}/#{package} && if [ -f install.rb ]; then ruby ./install.rb; else true; fi"
end

package_names = options[:plugins].collect { |repo| repo[/([^\/]*)\.git/, 1] }
pluginlibpath = package_names.map { |plugin| File.join(SourcePath, plugin, "lib") }
hosts.each do |host|
  host['pluginlibpath'] = pluginlibpath

  step "Clean and create #{SourcePath}"
  on host, "rm -rf #{SourcePath} && mkdir -vp #{SourcePath}"

  install_from_git host, :facter, FacterRepo, FacterRev
  install_from_git host, :puppet, PuppetRepo, PuppetRev

  package_names.zip(options[:plugins]).each do |package, repo|
    install_from_git host, package, repo, 'master'
  end

  step "grab git repo versions"
  version = {}
  [:puppet, :facter].each do |package|
    on host, "cd /opt/puppet-git-repos/#{package} && git describe" do
      version[package] = stdout.chomp
    end
  end
  config[:version] = version

  step "Create required users and groups"
  on host, "getent group puppet || groupadd puppet"
  on host, "getent passwd puppet || useradd puppet -g puppet -G puppet"

  step "REVISIT: Work around bug #5794 not creating reports as required"
  on host, "mkdir -vp /tmp/reports && chown -v puppet:puppet /tmp/reports"
end

# Git based install assume puppet master named "puppet";
# create an puppet.conf file with server= entry
step "Agents: create basic puppet.conf"
role_master=""
hosts.each do |host|
  role_master = host if host['roles'].include? 'master'
end
on agents, "echo [agent] >> /etc/puppet/puppet.conf && echo server=#{role_master} >> /etc/puppet/puppet.conf"
