require 'lib/puppet_acceptance/dsl/install_utils'

test_name "Install packages and repositories on target machines..." do
  extend PuppetAcceptance::DSL::InstallUtils

  SourcePath  = PuppetAcceptance::DSL::InstallUtils::SourcePath
  GitURI      = PuppetAcceptance::DSL::InstallUtils::GitURI
  GitHubSig   = PuppetAcceptance::DSL::InstallUtils::GitHubSig

  tmp_repositories = []
  options[:packages].each do |uri|
    raise(ArgumentError, "#{uri} is not recognized.") unless(uri =~ GitURI)
    tmp_repositories << extract_repo_info_from(uri)
  end

  repositories = order_packages(tmp_repositories)

  versions = {}
  hosts.each_with_index do |host, index|
    on host, "echo #{GitHubSig} >> $HOME/.ssh/known_hosts"

    repositories.each do |repository|
      step "Install #{repository[:name]}"
      install_from_git host, SourcePath, repository

      if index == 1
        versions << find_git_repo_versions(host, SourcePath, repository)
      end
    end
  end

  config[:version] = versions

  # Git based install assume puppet master named "puppet";
  # create an puppet.conf file with server= entry
  step "Agents: create basic puppet.conf" do
    agents.each do |agent|
      puppetconf = File.join(agent['puppetpath'], 'puppet.conf')

      on agent, "echo '[agent]' > #{puppetconf} && " +
                "echo server=#{master} >> #{puppetconf}"
    end
  end

  # these workarounds should not be part of a standard install step
  hosts.each do |host|
    next if host['platform'].include? 'windows'

    step "REVISIT: see #9862, this step should not be required for agents" do
      on host, "getent group puppet || groupadd puppet"

      if host['platform'].include? 'solaris'
        useradd_opts = '-d /puppet -m -s /bin/sh -g puppet puppet'
      else
        useradd_opts = 'puppet -g puppet -G puppet'
      end

      on host, "getent passwd puppet || useradd #{useradd_opts}"
    end

    step "REVISIT: Work around bug #5794 not creating reports as required" do
      on host, "mkdir -p /tmp/reports && chown puppet:puppet /tmp/reports"
    end
  end
end
