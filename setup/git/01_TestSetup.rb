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
  target = "#{SourcePath}/#{package}"

  step "Clone #{repo} if needed"
  on host, "test -d #{SourcePath} || mkdir -p #{SourcePath}"
  on host, "test -d #{target} || git clone #{repo} #{target}"

  step "Update #{package} and check out revision #{revision}"
  commands = ["cd #{target}",
              "remote rm origin",
              "remote add origin #{repo}",
              "fetch origin",
              "clean -fdx",
              "checkout -f #{revision}"]
  on host, commands.join(" && git ")

  step "Install #{package} on the system"
  on host, "cd #{target} && if [ -f install.rb ]; then ruby ./install.rb; else true; fi"
end


github_sig='github.com,207.97.227.239 ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ=='
package_names = options[:plugins].collect { |repo| repo[/([^\/]*)\.git/, 1] }
pluginlibpath = package_names.map { |plugin| File.join(SourcePath, plugin, "lib") }
hosts.each do |host|
  # FIXME: not very elegant, but pressed for time
  on host, "echo #{github_sig} >> $HOME/.ssh/known_hosts"
  host['pluginlibpath'] = pluginlibpath

  step "Install facter from git"
  install_from_git host, :facter, FacterRepo, FacterRev
  step "Install puppet from git"
  install_from_git host, :puppet, PuppetRepo, PuppetRev

  package_names.zip(options[:plugins]).each do |package, repo|
    step "Install #{package} plugin from git"
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

  step "REVISIT: see #9862, this step should not be required for agents"
  unless host['platform'].include? 'windows'
    step "Create required users and groups"
    on host, "getent group puppet || groupadd puppet"
    on host, "getent passwd puppet || useradd puppet -g puppet -G puppet"

    step "REVISIT: Work around bug #5794 not creating reports as required"
    on host, "mkdir -vp /tmp/reports && chown -v puppet:puppet /tmp/reports"
  end
end

# Git based install assume puppet master named "puppet";
# create an puppet.conf file with server= entry
step "Agents: create basic puppet.conf"
role_master=""
hosts.each do |host|
  role_master = host if host['roles'].include? 'master'
end

agents.each do |agent|
  puppetconf = File.join(agent['puppetpath'], 'puppet.conf')
  on agent, "echo [agent] > #{puppetconf} && echo server=#{role_master} >> #{puppetconf}"
end
