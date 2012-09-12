test_name "Install puppet and facter on target machines..."

SourcePath = "/opt/puppet-git-repos"
RootPath = File.expand_path(File.join(File.dirname(__FILE__), '/../../..'))
FacterRepo = File.join(RootPath, 'facter')
PuppetRepo = File.join(RootPath, 'puppet')

def get_tar_file(source_dir, prefix)
  # TODO: use Ruby's standard temp file mechanism
  `cd #{source_dir} && git archive --format=tar --prefix=#{prefix}/ HEAD -o /tmp/data.tar`
  '/tmp/data.tar'
end

hosts.each do |host|
  step "Install ruby"
  if host[:platform]
    if host[:platform].include? 'solaris'
      on host, "pkg install ruby-18"
    else
      on host, "apt-get install ruby-full -y"
    end
  end

  step "Clean and create #{SourcePath}"
  on host, "rm -rf #{SourcePath} && mkdir -vp #{SourcePath}"

  step "Copy #{FacterRepo}"
  scp_to host, get_tar_file(FacterRepo, 'facter'), "#{SourcePath}/facter.tar"

  step "Untar #{FacterRepo}"
  on host, "cd #{SourcePath} && tar xf facter.tar"

  step "Install facter on the system"
  on host, "cd #{SourcePath}/facter && ruby ./install.rb --bindir=/usr/bin --sbindir=/usr/sbin"

  step "Copy #{PuppetRepo}"
  scp_to host, get_tar_file(PuppetRepo, 'puppet'), "#{SourcePath}/puppet.tar"

  step "Untar #{PuppetRepo}"
  on host, "cd #{SourcePath} && tar xf puppet.tar"

  step "Install puppet on the system"
  on host, "cd #{SourcePath}/puppet && ruby ./install.rb --bindir=/usr/bin --sbindir=/usr/sbin"

  step "REVISIT: see #9862, this step should not be required for agents"
  unless host['platform'].include? 'windows'
    step "Create required users and groups"
    on host, "getent group puppet || groupadd puppet"
    if host[:platform].include? 'solaris'
      on host, "getent passwd puppet || useradd -d /puppet -m -s /bin/sh -g puppet puppet"
    else
      on host, "getent passwd puppet || useradd puppet -g puppet -G puppet"
    end

    step "REVISIT: Work around bug #5794 not creating reports as required"
    on host, "mkdir -vp /tmp/reports && chown -v puppet:puppet /tmp/reports"
  end
end
