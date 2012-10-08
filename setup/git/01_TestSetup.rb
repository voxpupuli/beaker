require 'pathname'

require 'lib/puppet_acceptance/dsl/install_utils'

extend PuppetAcceptance::DSL::InstallUtils

test_name "Install puppet and facter on target machines..."

SourcePath  = PuppetAcceptance::DSL::InstallUtils::SourcePath
GitHub      = 'git://github.com/puppetlabs'
IsURI       = %r{^[^:]+://|^git@github.com:}
IsGitHubURI = %r{(https://github.com/[^/]+/[^/]+)(?:/tree/(.*))$}

def extract_repo_info_from uri
  project = {}
  if match = IsGitHubURI.match(uri) then
    project[:name] = Pathname.new(match[1]).basename
    project[:path] = match[1] + '.git'
    project[:rev] = match[2] || 'origin/master'
  elsif yagr_uri =~ IsURI then
    repo, rev = uri.split('#', 2)
    project[:name] = Pathname.new(repo).basename
    project[:path] = repo
    project[:rev]  = rev || 'HEAD'
  else
    raise "Unsupported uri: '#{uri}'"
  end
  return project
end

def find_git_repo_versions host, repository
  step "Grab version for #{repository}"
  version = {}
  on host, "cd /opt/puppet-git-repos/#{respository[:name]} && " +
            "git describe || true" do |result|
    version[respository[:name]] = result.stdout.chomp
  end
  version
end

github_sig='github.com,207.97.227.239 ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ=='

repositories = []
options[:packages].each do |uri|
  repositories << extract_repo_info_from uri
end

versions = {}
hosts.each_with_index do |host, index|
  on host, "echo #{github_sig} >> $HOME/.ssh/known_hosts"

  repositories.each do |repository|
    step "Install #{repository}"
    install_from_git( host, repository[:name],
                      repository[:path], repository[:rev])

    versions << find_git_repo_versions(host, repository) if index == 1
  end
end

config[:version] = versions

# these workarounds should not be part of a standard install step
hosts.each do |host|
  step "REVISIT: see #9862, this step should not be required for agents"
  unless host['platform'].include? 'windows'
    step "Create required users and groups"
    on host, "getent group puppet || groupadd puppet"
    if host['platform'].include? 'solaris'
      on host, "getent passwd puppet || useradd -d /puppet -m -s /bin/sh -g puppet puppet"
    else
      on host, "getent passwd puppet || useradd puppet -g puppet -G puppet"
    end

    step "REVISIT: Work around bug #5794 not creating reports as required"
    if host['platform'].include? 'solaris'
      on host, "mkdir -p /tmp/reports && chown puppet:puppet /tmp/reports"
    else
      on host, "mkdir -vp /tmp/reports && chown -v puppet:puppet /tmp/reports"
    end
  end
end

# Git based install assume puppet master named "puppet";
# create an puppet.conf file with server= entry
step "Agents: create basic puppet.conf"
agents.each do |agent|
  puppetconf = File.join(agent['puppetpath'], 'puppet.conf')
  on agent, "echo '[agent]' > #{puppetconf} && " +
            "echo server=#{master} >> #{puppetconf}"
end
